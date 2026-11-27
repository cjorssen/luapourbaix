-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Pure thermodynamic closure in reaction space. Input is a prepared snapshot;
-- the caller owns it. No engine services, concentrations or boundary equations.
local database = ...
if type(database) ~= "table" then database = require("luapourbaix-database") end
local M = { database = database }
local ln10 = math.log(10)
-- Exact SI defining constants: k_B/e = R/F (NIST, SI 2019).
local gas_over_faraday = 1.380649e-23 / 1.602176634e-19
local stoichiometric_tolerance = 1e-12

local function fail(message)
  error("luapourbaix: " .. message, 0)
end

local function finite(value)
  if value ~= value or math.abs(value) == math.huge then
    fail("thermodynamic arithmetic exceeded the finite numerical range")
  end
  return value
end

local function add(vector, key, value)
  vector[key] = finite((vector[key] or 0) + value)
  if vector[key] == 0 then vector[key] = nil end
end

local function gcd(a, b)
  while b ~= 0 do a, b = b, a % b end
  return a
end

-- Positive coefficients are products; negative coefficients are reactants.
-- Primitive integer element balance fixes the normalization of every K.
function M.reaction(diagram, first, second)
  local a, b = diagram.species_by_id[first], diagram.species_by_id[second]
  if diagram.element == "H" or diagram.element == "O" then
    return nil, "H/O target requires an explicit reaction model"
  end
  local divisor = gcd(a.element_count, b.element_count)
  local ca, cb = b.element_count / divisor, a.element_count / divisor
  local vector = { [first] = -ca, [second] = cb }
  local atoms = {}
  for symbol, count in pairs(a.composition) do add(atoms, symbol, -ca * count) end
  for symbol, count in pairs(b.composition) do add(atoms, symbol, cb * count) end
  for symbol, count in pairs(atoms) do
    if symbol ~= "H" and symbol ~= "O" and count ~= 0 then
      return nil, "additional reaction participants required (unbalanced " .. symbol .. ")"
    end
  end
  local water = -(atoms.O or 0)
  local proton = -(atoms.H or 0) - 2 * water
  local electron = cb * b.charge - ca * a.charge + proton
  add(vector, "H2O(l)", water)
  add(vector, "H^+", proton)
  add(vector, "e^-", electron)
  local expected = ca * a.element_count * (b.oxidation_number - a.oxidation_number)
  if (electron == 0 and a.oxidation_number ~= b.oxidation_number) or
    math.abs(electron - expected) > 1e-10 * math.max(1, math.abs(expected)) then
    return nil, "oxidation assignments and H+/H2O electron balance disagree"
  end
  for _, value in pairs(vector) do
    if math.abs(value) > 9007199254740991 then fail("reaction coefficient is too large") end
  end
  return { first = first, second = second, coefficients = vector,
    electrons = -electron }
end

local function solubility(diagram, constant)
  local solid = diagram.species_by_id[constant.solid]
  local atoms, count = solid.composition, solid.element_count
  for symbol in pairs(atoms) do
    if symbol ~= diagram.element and symbol ~= "H" and symbol ~= "O" then
      fail("solubility product for " .. solid.id .. ": explicit dissolution reaction required")
    end
  end
  local hydroxide = atoms.O or 0
  if diagram.element == "H" or diagram.element == "O" or hydroxide == 0 or
    atoms.H ~= hydroxide or hydroxide % count ~= 0 then
    fail("solubility product for " .. solid.id .. ": only hydroxide dissolution is inferred; " ..
      "supply reaction on this record or an equilibrium constant for a balanced species pair")
  end
  local charge = hydroxide / count
  if solid.oxidation_number ~= charge then fail("hydroxide oxidation assignment is inconsistent") end
  local ion = diagram.element .. "^" .. (charge == 1 and "" or string.format("%.0f", charge)) .. "+"
  -- The free ion is a reaction participant, never an added diagram domain.
  return { [solid.id] = -1, [ion] = count, ["OH^-"] = hydroxide }
end

local function sorted_keys(vector)
  local keys = {}
  for key in pairs(vector) do keys[#keys + 1] = key end
  table.sort(keys)
  return keys
end

local function row(vector, value, source)
  local result = { coefficients = {}, value = value, sources = {} }
  for key, coefficient in pairs(vector) do result.coefficients[key] = coefficient end
  if source then result.sources[source] = 1 end
  return result
end

local function subtract(target, source, multiplier)
  for key, value in pairs(source.coefficients) do
    add(target.coefficients, key, -multiplier * value)
  end
  target.value = finite(target.value - multiplier * source.value)
  for key, value in pairs(source.sources) do add(target.sources, key, -multiplier * value) end
end

function M.check(diagram)
  local factor = finite(diagram.nernst_factor or gas_over_faraday * diagram.temperature * ln10)
  if factor <= 0 then fail("temperature is outside the thermodynamic numerical range") end
  local inputs, columns, direct = {}, {}, {}
  local water = { ["H2O(l)"] = -1, ["H^+"] = 1, ["OH^-"] = 1 }
  local function input(vector, value, label, metadata)
    local index = #inputs + 1
    local item = row(vector, finite(value), index)
    item.label = label
    item.metadata = metadata or { origin = "user" }
    inputs[index] = item
    for key in pairs(vector) do columns[key] = true end
  end
  for index, constant in ipairs(diagram.constants) do
    local vector, value
    if constant.reaction_coefficients then
      if constant.kind == "equilibrium constant" and
        diagram.species_by_id[constant.first].oxidation_number ~=
        diagram.species_by_id[constant.second].oxidation_number then
        fail("equilibrium constant requires equal oxidation numbers")
      end
      vector, value = constant.reaction_coefficients, constant.log_value
    elseif constant.kind == "water ion product" then
      vector, value = water, constant.log_value
    elseif constant.kind == "solubility product" then
      vector, value = solubility(diagram, constant), constant.log_value
    else
      local first = constant.oxidized or constant.first
      local second = constant.reduced or constant.second
      local reaction, reason = M.reaction(diagram, first, second)
      if not reaction then fail("constant " .. index .. ": " .. reason .. " for " .. first .. " / " .. second) end
      vector = reaction.coefficients
      if constant.kind == "standard potential" then
        value = reaction.electrons * constant.value / factor
      else
        if reaction.electrons ~= 0 then fail("equilibrium constant requires equal oxidation numbers") end
        value = constant.log_value
      end
      direct[first .. "\0" .. second] = true
    end
    input(vector, value, "constant " .. index .. " (" .. constant.kind .. ")",
      {origin="user", reaction=constant.reaction})
  end
  local basis, keys = {}, sorted_keys(columns)
  local function reduce(item)
    for _, key in ipairs(keys) do
      local coefficient = item.coefficients[key] or 0
      if basis[key] and coefficient ~= 0 then
        subtract(item, basis[key], coefficient)
        item.coefficients[key] = nil
      end
    end
    for key, value in pairs(item.coefficients) do
      if math.abs(value) < stoichiometric_tolerance then item.coefficients[key] = nil end
    end
    return item
  end
  local function insert(original)
    local item = row(original.coefficients, original.value)
    for key, value in pairs(original.sources) do item.sources[key] = value end
    reduce(item)
    local pivot = sorted_keys(item.coefficients)[1]
    if pivot then
      local scale = item.coefficients[pivot]
      for key, value in pairs(item.coefficients) do item.coefficients[key] = finite(value / scale) end
      for key, value in pairs(item.sources) do item.sources[key] = finite(value / scale) end
      item.value = finite(item.value / scale)
      basis[pivot] = item
    elseif math.abs(item.value) > diagram.thermodynamic_tolerance then
      fail("inconsistent thermodynamic cycle at " .. original.label ..
        "; log10(K) residual = " .. string.format("%.10g", item.value) ..
        " (tolerance " .. diagram.thermodynamic_tolerance .. ")")
    end
  end
  for _, original in ipairs(inputs) do insert(original) end
  local function query(vector)
    local item = reduce(row(vector, 0))
    if next(item.coefficients) then return nil end
    local sources = {}
    for _, index in ipairs(sorted_keys(item.sources)) do
      local coefficient = -item.sources[index]
      if coefficient ~= 0 then
        sources[#sources + 1] = { index = index, coefficient = coefficient }
      end
    end
    -- Verify the reconstructed reaction, not only an eliminated residual.
    -- This prevents cleanup of tiny pivots from certifying a false span match.
    local residual = {}
    for key, value in pairs(vector) do residual[key] = -value end
    for _, source in ipairs(sources) do
      for key, value in pairs(inputs[source.index].coefficients) do
        add(residual, key, source.coefficient * value)
      end
    end
    for key, value in pairs(residual) do
      if math.abs(value) > 1e-9 * math.max(1, math.abs(vector[key] or 0)) then
        return nil, "reaction combination is unresolved at working numerical precision"
      end
    end
    return { log_k = -item.value, sources = sources }
  end
  local water_result = query(water)
  if not water_result and diagram.temperature == 298.15 then
    input(water, -14, "water ion product default at 298.15 K", { origin = "default" })
    keys = sorted_keys(columns)
    insert(inputs[#inputs])
    water_result = query(water)
    if not water_result then fail("water reaction is unresolved at working numerical precision") end
    water_result.status = "default"
  elseif water_result then
    water_result.status = "derived"
    for _, constant in ipairs(diagram.constants) do
      if constant.kind == "water ion product" then water_result.status = "provided" end
    end
  end
  -- Resolve supplied data first. Library rows only extend the reaction span;
  -- dependent rows cannot override supplied or already derivable constants.
  local queries = {}
  for _, boundary in ipairs(diagram.boundaries) do
    local first, second = boundary.first, boundary.second
    if boundary.kind == "redox" then first, second = second, first end
    local reaction, reason = M.reaction(diagram, first, second)
    queries[#queries + 1] = { boundary = boundary, reaction = reaction, reason = reason,
      first = first, second = second }
  end
  local function complete()
    for _, item in ipairs(queries) do
      if item.reaction and not query(item.reaction.coefficients) then return false end
    end
    return true
  end
  local candidates, phases = database.candidates(diagram)
  local consulted = false
  if not complete() then
    consulted = diagram.thermodynamic_database ~= "none"
    for _, record in ipairs(candidates) do
      if not query(record.coefficients) then
        local value = record.log_value or record.electrons * record.value / factor
        input(record.coefficients, value, "database " .. record.id,
          { origin = "database", record = record })
        keys = sorted_keys(columns)
        insert(inputs[#inputs])
        if complete() then break end
      end
    end
  end
  local function status(result, provided)
    if provided then return "provided" end
    if #result.sources == 1 and result.sources[1].coefficient == 1 and
      inputs[result.sources[1].index].metadata.origin == "database" then return "database" end
    return "derived"
  end
  local missing = {}
  for _, item in ipairs(queries) do
    local boundary, reaction, reason = item.boundary, item.reaction, item.reason
    local first, second = item.first, item.second
    local result, numerical_reason
    if reaction then result, numerical_reason = query(reaction.coefficients) end
    reason = reason or numerical_reason
    if result then
      result.reaction = reaction
      result.status = status(result, direct[first .. "\0" .. second])
      if reaction.electrons ~= 0 then
        result.standard_potential = finite(factor * result.log_k / reaction.electrons)
      else
        local value = 10 ^ result.log_k
        if value > 0 and value < math.huge then result.equilibrium_constant = value end
        if diagram.species_by_id[first].phase == "aqueous" and
          diagram.species_by_id[second].phase == "aqueous" and
          reaction.coefficients[first] == -1 and reaction.coefficients[second] == 1 and
          reaction.coefficients["H^+"] == 1 then result.pka = -result.log_k end
      end
      boundary.thermodynamics = result
    else
      local datum = boundary.kind == "redox" and "standard potential" or "equilibrium constant"
      missing[#missing + 1] = boundary.name .. " [" .. first .. " -> " .. second .. "]: " ..
        (reason or ("missing independent " .. datum .. " or equivalent reaction data"))
    end
  end
  if #missing > 0 then
    local hint = ""
    for _, constant in ipairs(diagram.constants) do
      if constant.kind == "solubility product" and not water_result then
        hint = "\nWater ion product is not supplied or derivable; it may be needed to convert hydroxide data."
      end
    end
    if consulted then
      hint = hint .. "\nDatabase aqueous-298 was searched at " .. diagram.temperature .. " K."
      if #candidates == 0 then hint = hint .. " No matching temperature/species/phase records." end
      for _, id in ipairs(sorted_keys(phases)) do hint = hint .. "\nLookup phase: " .. id .. " = " .. phases[id] end
    end
    fail("insufficient thermodynamic data:\n" .. table.concat(missing, "\n") .. hint)
  end
  local solubilities = {}
  for _, species in ipairs(diagram.species) do
    if species.phase == "solid" then
      local explicit
      for _,constant in ipairs(diagram.constants) do
        if constant.kind == "solubility product" and constant.solid == species.id then
          explicit=constant.reaction_coefficients
        end
      end
      local ok, vector = true, explicit
      if not explicit then ok, vector = pcall(solubility, diagram, { solid = species.id }) end
      if ok then
        local result = query(vector)
        if result then
          result.status = status(result)
          for _, constant in ipairs(diagram.constants) do
            if constant.kind == "solubility product" and constant.solid == species.id then
              result.status = "provided"
            end
          end
          local value = 10 ^ result.log_k
          if value > 0 and value < math.huge then result.value = value end
          solubilities[species.id] = result
        end
      end
    end
  end
  if water_result then
    local value = 10 ^ water_result.log_k
    if value > 0 and value < math.huge then water_result.value = value end
  end
  local formations = {}
  for _, record in ipairs(candidates) do
    if record.kind == "hydroxide formation" and diagram.species_by_id[record.second] then
      local result = query(record.coefficients)
      if result then
        result.status = status(result)
        local value = 10 ^ result.log_k
        if value > 0 and value < math.huge then result.value = value end
        formations[record.second] = result
      end
    end
  end
  diagram.thermodynamics = { checked = true, water = water_result, solubilities = solubilities,
    formations = formations, database = diagram.thermodynamic_database,
    database_version = database.version, database_sources = database.sources(),
    database_consulted = consulted, phases = phases,
    tolerance = diagram.thermodynamic_tolerance, input_count = #inputs, inputs = inputs }
  return diagram
end

return M
