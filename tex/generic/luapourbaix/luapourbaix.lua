-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Pure limiting-diagram model, including selection; no automatic rendering.
local thermodynamics, equations, selection = ...
if type(thermodynamics) ~= "table" then
  thermodynamics = require("luapourbaix-thermodynamics")
end
equations = equations or require("luapourbaix-equations")
selection = selection or require("luapourbaix-selection")
local M = { version = "1.0", database = thermodynamics.database }

local elements = {}
for symbol in ("H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr " ..
  "Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In " ..
  "Sn Sb Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf Ta W " ..
  "Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U Np Pu Am Cm Bk Cf " ..
  "Es Fm Md No Lr Rf Db Sg Bh Hs Mt Ds Rg Cn Nh Fl Mc Lv Ts Og"):gmatch("%S+") do
  elements[symbol] = true
end

local function fail(message)
  error("luapourbaix: " .. message, 0)
end

local function text(value, field)
  if type(value) ~= "string" then
    fail(field .. " must be text")
  end
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function copy(value, memo)
  if type(value) ~= "table" then
    return value
  end
  memo = memo or {}
  if memo[value] then
    return memo[value]
  end
  local result = {}
  memo[value] = result
  for key, item in pairs(value) do
    result[key] = copy(item, memo)
  end
  return result
end

local function number(value, field, positive)
  if type(value) == "string" then
    value = text(value, field)
    local mantissa, exponent = value:match("^(.-)[eE]([+-]?%d+)$")
    if not mantissa then
      mantissa = value
    end
    if not (mantissa:match("^[+-]?%d+%.?%d*$") or
      mantissa:match("^[+-]?%.%d+$")) then
      fail(field .. " must be a decimal number (optional e exponent)")
    end
    value = tonumber(mantissa .. (exponent and "e" .. exponent or ""))
  end
  if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
    fail(field .. " must be finite")
  end
  if positive and value <= 0 then
    fail(field .. " must be positive")
  end
  return value
end

-- Formula grammar: symbols, positive integer subscripts and parenthesized
-- groups. TeX macros and formula-formatting commands are not chemical data.
local function composition(formula)
  local position = 1
  local function multiplier()
    local digits = formula:sub(position):match("^%d+")
    if not digits then
      return 1
    end
    position = position + #digits
    local n = tonumber(digits)
    if n < 1 or n > 9007199254740991 then
      fail("invalid stoichiometric subscript in " .. formula)
    end
    return n
  end
  local function group(nested)
    local atoms, terms = {}, 0
    while position <= #formula do
      local char = formula:sub(position, position)
      local part
      if char == ")" then
        if not nested then
          fail("unmatched closing parenthesis in " .. formula)
        end
        break
      elseif char == "(" then
        position = position + 1
        part = group(true)
        if formula:sub(position, position) ~= ")" then
          fail("unclosed group in " .. formula)
        end
        position = position + 1
      else
        local symbol = formula:sub(position):match("^[A-Z][a-z]?")
        if not symbol or not elements[symbol] then
          fail("invalid element or formula syntax in " .. formula)
        end
        position = position + #symbol
        part = { [symbol] = 1 }
      end
      local n = multiplier()
      for symbol, count in pairs(part) do
        local previous = atoms[symbol] or 0
        if count > math.floor((9007199254740991 - previous) / n) then
          fail("stoichiometric count is too large in " .. formula)
        end
        atoms[symbol] = previous + n * count
      end
      terms = terms + 1
    end
    if terms == 0 then
      fail("empty formula or group in " .. formula)
    end
    return atoms
  end
  return group(false)
end

function M.parse_species(value, element)
  value = text(value, "species")
  local body, phase = value:match("^(.-)%((aq)%)$")
  if not body then
    body, phase = value:match("^(.-)%((s)%)$")
  end
  body = body or value
  body = body:gsub("%^%{(%d*[+-])%}$", "^%1")
  local formula, magnitude, sign = body:match("^(.-)%^(%d*)([+-])$")
  local charge = 0
  if formula then
    magnitude = magnitude == "" and 1 or tonumber(magnitude)
    if magnitude < 1 or magnitude > 9007199254740991 then
      fail("invalid charge in " .. value)
    end
    charge = (sign == "+" and 1 or -1) * magnitude
  else
    formula = body
  end
  if not phase and charge == 0 then
    fail("neutral species require (aq) or (s): " .. value)
  end
  phase = phase == "s" and "solid" or "aqueous"
  if phase == "solid" and charge ~= 0 then
    fail("solid species must be electrically neutral: " .. value)
  end
  local atoms = composition(formula)
  if not atoms[element] then
    fail("species " .. value .. " does not contain element " .. tostring(element))
  end
  local suffix = charge ~= 0 and ("^" ..
    (math.abs(charge) == 1 and "" or tostring(math.abs(charge))) .. sign) or ""
  local id = formula .. suffix .. (phase == "solid" and "(s)" or
    (charge == 0 and "(aq)" or ""))
  return { id = id, formula = formula, phase = phase, charge = charge,
    composition = atoms, element_count = atoms[element] }
end

-- Explicit non-redox equations use spaced plus separators, never TeX source.
-- Rational coefficients are checked through a bounded common integer scale.
local function parse_reaction(value, constant, element)
  local source = text(value, "reaction")
  local left, right = source:match("^([^=]+)=([^=]+)$")
  if not left then fail("reaction requires exactly one = and two nonempty sides") end
  local terms, scale = {}, 1
  local limit = 9007199254740991
  local function bounded(n)
    if math.abs(n) > limit then fail("reaction integer arithmetic exceeds exact range") end
    return n
  end
  local function gcd(a,b)
    while b ~= 0 do a,b=b,a%b end
    return a
  end
  for side, body in ipairs({left,right}) do
    local rest, position = text(body,"reaction side"), 0
    repeat
      local first,last = rest:find("%s+%+%s+")
      local term = text(first and rest:sub(1,first-1) or rest,"reaction term")
      position = position + 1
      local n,d,id = term:match("^(%d+)/(%d+)%s+(.+)$")
      if not n then n,id=term:match("^(%d+)%s+(.+)$"); d="1" end
      if not n then n,d,id="1","1",term end
      n,d=tonumber(n),tonumber(d)
      if n < 1 or d < 1 then fail("reaction coefficients must be positive integers or fractions") end
      bounded(n); bounded(d)
      local divisor=gcd(n,d); n,d=n/divisor,d/divisor
      scale=bounded(scale*(d/gcd(scale,d)))
      id=id:gsub("%^%{(%d*[+-])%}","^%1")
      if id == "HO^-" or id == "HO^-(aq)" then id="OH^-" end
      if id == "H2O" then id="H2O(l)" end
      if id == "e^-" then fail("reaction must be non-redox: electrons are not allowed") end
      local species
      if id == "H2O(l)" then
        species={id=id,composition={H=2,O=1},charge=0,phase="liquid"}
      else
        local ok,result=pcall(M.parse_species,id,id:match("([A-Z][a-z]?)"))
        if not ok then fail("reaction side " .. side .. ", term " .. position .. ": " .. tostring(result) ..
          "; separate participants with spaced + and coefficients with whitespace") end
        species=result
      end
      terms[#terms+1]={species=species,n=(side==1 and -n or n),d=d}
      rest=first and text(rest:sub(last+1),"reaction term") or nil
    until rest == nil
  end
  local integers, atoms, charge, species_by_id = {}, {}, 0, {}
  for _,term in ipairs(terms) do
    local species=term.species
    local c=bounded(term.n*(scale/term.d))
    integers[species.id]=bounded((integers[species.id] or 0)+c)
    species_by_id[species.id]=species
    charge=bounded(charge+bounded(c*species.charge))
    for symbol,count in pairs(species.composition) do
      atoms[symbol]=bounded((atoms[symbol] or 0)+bounded(c*count))
    end
  end
  for symbol,balance in pairs(atoms) do
    if balance ~= 0 then fail("reaction is unbalanced for element " .. symbol) end
  end
  if charge ~= 0 then fail("reaction is unbalanced for electric charge") end
  local vector={}
  for id,c in pairs(integers) do if c ~= 0 then vector[id]=c/scale end end
  if not next(vector) then fail("reaction has an empty net equation") end
  if constant.kind == "solubility product" then
    if not vector[constant.solid] or vector[constant.solid] >= 0 then
      fail("solubility reaction must consume the addressed solid")
    end
    for id,c in pairs(vector) do
      if id ~= constant.solid and id ~= "H2O(l)" and
        (c < 0 or species_by_id[id].phase ~= "aqueous") then
        fail("solubility reaction must dissolve the solid into aqueous products; use an equilibrium constant for acid dissolution")
      end
    end
  else
    local a,b=vector[constant.first],vector[constant.second]
    if not a or not b or a*b >= 0 then
      fail("reaction must place the addressed pair on opposite sides")
    end
    for id in pairs(vector) do
      if species_by_id[id].composition[element] and id ~= constant.first and id ~= constant.second then
        fail("equilibrium reaction contains an additional carrier of the selected element: " .. id)
      end
    end
  end
  return source,vector
end

local function species_list(value)
  if type(value) == "table" then
    return value
  end
  value = text(value, "species")
  local result = {}
  for item in (value .. ","):gmatch("(.-),") do
    if text(item, "species") == "" then
      fail("species list contains an empty entry")
    end
    result[#result + 1] = item
  end
  return result
end

local function array(value, field)
  if type(value) ~= "table" then
    fail(field .. " must be an array")
  end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
      fail(field .. " must be a dense array")
    end
    count = count + 1
  end
  for i = 1, count do
    if value[i] == nil then
      fail(field .. " must be a dense array")
    end
  end
  return value
end

-- Validate structure, not thermodynamic sufficiency or consistency.
function M.declare(raw)
  if type(raw) ~= "table" then
    fail("declaration must be a table")
  end
  local element = text(raw.element or "", "element")
  if not elements[element] then
    fail("element must be a chemical element symbol")
  end
  local name = text(raw.name or "", "name")
  if name ~= "" and not name:match("^[A-Za-z][A-Za-z0-9_.:-]*$") then
    fail("name must start with a letter and contain letters, digits, _, ., :, or -")
  end
  local activity_model = text(raw.activity_model or "", "activity model")
  if activity_model ~= "" and activity_model ~= "ideal" then
    fail("activity model must be ideal when specified")
  end
  local convention = text(raw.boundary_convention or "", "boundary convention")
  if convention ~= "equal concentrations" and
    convention ~= "equal element concentrations" then
    fail("boundary convention must explicitly be 'equal concentrations' or " ..
      "'equal element concentrations'")
  end
  local diagram = {
    activity_model = activity_model ~= "" and activity_model or "ideal",
    schema_version = 7, name = name ~= "" and name or nil, element = element,
    concentration = number(raw.concentration, "concentration", true),
    concentration_unit = "mol/L", boundary_convention = convention,
    temperature = number(raw.temperature, "temperature (K)", true),
    temperature_unit = "K",
    thermodynamic_tolerance = number(raw.thermodynamic_tolerance or 1e-8,
      "thermodynamic tolerance", true),
    thermodynamic_database = text(raw.thermodynamic_database or "aqueous-298", "thermodynamic database"),
    model = "limiting", species = {}, species_by_id = {}, constants = {},
  }
  local nernst = raw.nernst_factor
  if nernst == nil or nernst == "auto" then
    diagram.nernst_factor = number((1.380649e-23 / 1.602176634e-19) *
      diagram.temperature * math.log(10), "Nernst factor (V)", true)
    diagram.nernst_factor_source = "temperature"
  else
    diagram.nernst_factor = number(nernst, "Nernst factor (V)", true)
    diagram.nernst_factor_source = "specified"
  end
  if diagram.thermodynamic_database ~= "aqueous-298" and diagram.thermodynamic_database ~= "none" then
    fail("thermodynamic database must be 'aqueous-298' or 'none'")
  end
  for _, entry in ipairs(array(species_list(raw.species), "species")) do
    local species = M.parse_species(entry, element)
    if diagram.species_by_id[species.id] then
      fail("duplicate species: " .. species.id)
    end
    diagram.species[#diagram.species + 1] = species
    diagram.species_by_id[species.id] = species
  end
  if #diagram.species == 0 then
    fail("species list must not be empty")
  end
  if type(raw.constants) ~= "table" then
    fail("constants must be supplied explicitly (an empty list is allowed)")
  end
  local function reference(value)
    local id = M.parse_species(value, element).id
    if not diagram.species_by_id[id] then
      fail("constant references undeclared species: " .. id)
    end
    return id
  end
  local seen = {}
  for _, entry in ipairs(array(raw.constants, "constants")) do
    if type(entry) ~= "table" then
      fail("constant must be a record")
    end
    local constant, key
    if entry.kind == "standard potential" then
      local oxidized, reduced = reference(entry.oxidized), reference(entry.reduced)
      if oxidized == reduced then
        fail("a standard potential requires two distinct species")
      end
      key = "E:" .. (oxidized < reduced and oxidized .. "/" .. reduced or
        reduced .. "/" .. oxidized)
      constant = { kind = entry.kind, oxidized = oxidized, reduced = reduced,
        value = number(entry.value, "standard potential", false), unit = "V" }
    elseif entry.kind == "solubility product" then
      local solid = reference(entry.solid)
      if diagram.species_by_id[solid].phase ~= "solid" then
        fail("solubility product requires a solid: " .. solid)
      end
      key = "Ks:" .. solid
      constant = { kind = entry.kind, solid = solid, unit = "1" }
    elseif entry.kind == "equilibrium constant" then
      local first, second = reference(entry.first), reference(entry.second)
      if first == second then fail("equilibrium constant requires two distinct species") end
      key = "K:" .. (first < second and first .. "/" .. second or second .. "/" .. first)
      constant = { kind = entry.kind, first = first, second = second, unit = "1" }
    elseif entry.kind == "water ion product" then
      key = "Kw"
      constant = { kind = entry.kind, unit = "1" }
    else
      fail("unknown constant kind: " .. tostring(entry.kind))
    end
    if entry.kind ~= "standard potential" then
      local has_value = entry.value ~= nil and entry.value ~= ""
      local has_log = entry.log_value ~= nil and entry.log_value ~= ""
      if has_value == has_log then fail(entry.kind .. " requires exactly one of value and log value") end
      if has_value then
        constant.value = number(entry.value, entry.kind, true)
        constant.log_value = math.log(constant.value) / math.log(10)
      else
        constant.log_value = number(entry.log_value, "log value")
        local value = 10 ^ constant.log_value
        if value > 0 and value < math.huge then constant.value = value end
      end
    end
    if entry.reaction ~= nil then
      if entry.kind ~= "solubility product" and entry.kind ~= "equilibrium constant" then
        fail("reaction is supported only for solubility products and equilibrium constants")
      end
      constant.reaction, constant.reaction_coefficients = parse_reaction(entry.reaction, constant, element)
    end
    if seen[key] then
      fail("duplicate thermodynamic constant: " .. key)
    end
    seen[key] = true
    diagram.constants[#diagram.constants + 1] = constant
  end
  return M.prepare(diagram, raw)
end

-- A fresh checked copy preserves the preparation snapshot if closure fails.
function M.check(diagram)
  return thermodynamics.check(copy(diagram))
end

local function species_reference(diagram, value)
  local id = M.parse_species(value, diagram.element).id
  local species = diagram.species_by_id[id]
  if not species then
    fail("undeclared species: " .. id)
  end
  return species
end

local function oxidation_value(value)
  if type(value) == "string" then
    local numerator, denominator = text(value, "oxidation number"):match("^([+-]?%d+)/(%d+)$")
    if numerator then
      return number(numerator, "oxidation numerator") /
        number(denominator, "oxidation denominator", true)
    end
  end
  return number(value, "oxidation number")
end

local function infer_oxidation(species, element)
  local other = 0
  for symbol in pairs(species.composition) do
    if symbol ~= element then other = other + 1 end
  end
  if other == 0 then
    if species.charge == 0 then return 0, "elemental species" end
    if species.element_count == 1 then return species.charge, "monatomic ion" end
  elseif element ~= "H" and element ~= "O" then
    local residual = species.charge
    for symbol, count in pairs(species.composition) do
      if symbol == "H" then
        residual = residual - count
      elseif symbol == "O" then
        residual = residual + 2 * count
      elseif symbol ~= element then
        fail("explicit oxidation number required for " .. species.id ..
          " (additional element " .. symbol .. ")")
      end
    end
    local value = residual / species.element_count
    if residual % species.element_count == 0 then return value, "H=+1, O=-2" end
  end
  fail("explicit oxidation number required for " .. species.id ..
    " (ambiguous or nonintegral automatic assignment)")
end

local function order_acidity(group, overrides, element)
  local explicit, comparable = 0, true
  if #group.species > 1 and (element == "H" or element == "O") then comparable = false end
  local reference = group.species[1]
  for _, species in ipairs(group.species) do
    local value = (overrides[species.id] or {}).acidity_rank
    if value ~= nil and value ~= "" then
      species.acidity_rank = number(value, "acidity rank", true)
      explicit = explicit + 1
    end
    -- Spectator compositions per atom of the selected element must agree.
    -- Otherwise H+, H2O and the two species do not suffice for comparison.
    local symbols = {}
    for symbol in pairs(reference.composition) do symbols[symbol] = true end
    for symbol in pairs(species.composition) do symbols[symbol] = true end
    for symbol in pairs(symbols) do
      if symbol ~= element and symbol ~= "H" and symbol ~= "O" and
        (reference.composition[symbol] or 0) / reference.element_count ~=
        (species.composition[symbol] or 0) / species.element_count then
        comparable = false
      end
    end
    species.acidity_index = ((species.composition.H or 0) -
      2 * (species.composition.O or 0)) / species.element_count
  end
  if explicit > 0 and explicit ~= #group.species then
    fail("acidity ranks must cover every species in an oxidation group")
  end
  if explicit == 0 and not comparable then
    fail("explicit acidity ranks required for oxidation group " .. group.oxidation_number ..
      " (H+/H2O comparison is not applicable)")
  end
  group.acidity_basis = explicit > 0 and "explicit ranks" or "H+/H2O stoichiometry"
  local used = {}
  for _, species in ipairs(group.species) do
    species.acidity_basis = group.acidity_basis
    if explicit > 0 then
      if used[species.acidity_rank] then fail("duplicate acidity rank in oxidation group") end
      used[species.acidity_rank] = true
      -- Do not expose a stoichiometric index as a validated comparison for
      -- incompatible ligands. The supplied order is the complete authority.
      species.acidity_index = nil
    end
  end
  table.sort(group.species, function(a, b)
    if explicit > 0 then return a.acidity_rank < b.acidity_rank end
    if a.acidity_index ~= b.acidity_index then return a.acidity_index > b.acidity_index end
    return a.id < b.id -- deterministic display order, not a chemical tie-break
  end)
end

local function alphabetic(index)
  local label = ""
  repeat
    index = index - 1
    label = string.char(97 + index % 26) .. label
    index = math.floor(index / 26)
  until index == 0
  return label
end

local function pair_key(a, b)
  return a < b and a .. "\0" .. b or b .. "\0" .. a
end

local function prepare_boundaries(diagram, raw)
  local labels = raw.boundary_labels or {}
  if type(labels) ~= "table" then fail("boundary labels must be a record") end
  local function fragment(value, default)
    local result = text(value == nil and default or value, "boundary label fragment")
    if not result:match("^[A-Za-z0-9_.:-]*$") then fail("invalid boundary label fragment") end
    return result
  end
  labels = { vertical_prefix = fragment(labels.vertical_prefix, ""),
    redox_prefix = fragment(labels.redox_prefix, ""), suffix = fragment(labels.suffix, "-temp") }
  diagram.boundary_labels = labels
  local overrides = {}
  for _, entry in ipairs(array(raw.boundary_names or {}, "boundary names")) do
    if type(entry) ~= "table" then fail("boundary name must be a record") end
    local a, b = species_reference(diagram, entry.first), species_reference(diagram, entry.second)
    if a.id == b.id then fail("boundary name requires two distinct species") end
    local key = pair_key(a.id, b.id)
    if overrides[key] then fail("duplicate boundary name override for a species pair") end
    local name = text(entry.name, "boundary name")
    if not name:match("^[A-Za-z0-9][A-Za-z0-9_.:-]*$") then fail("invalid boundary name") end
    overrides[key] = name
  end
  local vertical, redox = 0, 0
  diagram.boundaries, diagram.boundaries_by_name = {}, {}
  for i, a in ipairs(diagram.ordered_species) do
    for j = i + 1, #diagram.ordered_species do
      local b = diagram.ordered_species[j]
      local equal = a.oxidation_number == b.oxidation_number
      local label
      if equal then
        vertical = vertical + 1
        label = labels.vertical_prefix .. alphabetic(vertical) .. labels.suffix
      else
        redox = redox + 1
        label = labels.redox_prefix .. redox .. labels.suffix
      end
      label = overrides[pair_key(a.id, b.id)] or label
      if diagram.boundaries_by_name[label] then fail("duplicate boundary name: " .. label) end
      local boundary = { name = label, first = a.id, second = b.id,
        kind = equal and "vertical" or "redox",
        geometry = equal and "vertical candidate" or "horizontal or oblique candidate",
        law = equal and "equilibrium quotient" or "Nernst", provisional = true }
      diagram.boundaries[#diagram.boundaries + 1] = boundary
      diagram.boundaries_by_name[label] = boundary
    end
  end
end

-- Preparation is performed before a declaration is committed. It neither
-- evaluates a thermodynamic constant nor creates E(pH) coordinates.
function M.prepare(diagram, raw)
  local overrides = {}
  for _, entry in ipairs(array(raw.species_data or {}, "species data")) do
    if type(entry) ~= "table" then fail("species data must be a record") end
    local species = species_reference(diagram, entry.species)
    if overrides[species.id] then fail("duplicate species data: " .. species.id) end
    overrides[species.id] = entry
  end
  local groups, by_number = {}, {}
  for index, species in ipairs(diagram.species) do
    local entry = overrides[species.id] or {}
    species.index = index
    if entry.thermodynamic_phase ~= nil and entry.thermodynamic_phase ~= "" then
      local phase = text(entry.thermodynamic_phase, "thermodynamic phase")
      if species.phase ~= "solid" or not phase:match("^[a-z][a-z0-9-]*$") then
        fail("thermodynamic phase requires a solid and a lowercase identifier")
      end
      species.thermodynamic_phase = phase
    end
    if entry.oxidation_number ~= nil and entry.oxidation_number ~= "" then
      species.oxidation_number = oxidation_value(entry.oxidation_number)
      species.oxidation_basis = "explicit"
    else
      species.oxidation_number, species.oxidation_basis = infer_oxidation(species, diagram.element)
    end
    local state = species.oxidation_number
    local group = by_number[state]
    if not group then
      group = { oxidation_number = state, species = {} }
      by_number[state], groups[#groups + 1] = group, group
    end
    group.species[#group.species + 1] = species
  end
  table.sort(groups, function(a, b) return a.oxidation_number < b.oxidation_number end)
  diagram.ordered_species = {}
  for _, group in ipairs(groups) do
    order_acidity(group, overrides, diagram.element)
    for _, species in ipairs(group.species) do
      diagram.ordered_species[#diagram.ordered_species + 1] = species
    end
  end
  for _, constant in ipairs(diagram.constants) do
    if constant.kind == "standard potential" then
      if diagram.species_by_id[constant.oxidized].oxidation_number <=
        diagram.species_by_id[constant.reduced].oxidation_number then
        fail("standard potential requires oxidized oxidation number > reduced oxidation number")
      end
    end
  end
  diagram.oxidation_groups = groups
  prepare_boundaries(diagram, raw)
  return diagram
end

-- Analytic concentration assignment only; no Nernst relation is evaluated.
function M.aqueous_boundary_concentrations(diagram, first, second)
  local a = diagram.species_by_id[M.parse_species(first, diagram.element).id]
  local b = diagram.species_by_id[M.parse_species(second, diagram.element).id]
  if not a or not b or a.id == b.id or
    a.phase ~= "aqueous" or b.phase ~= "aqueous" then
    fail("aqueous boundary requires two distinct declared aqueous species")
  end
  if diagram.boundary_convention == "equal concentrations" then
    local c = diagram.concentration / (a.element_count + b.element_count)
    return c, c
  elseif diagram.boundary_convention == "equal element concentrations" then
    return diagram.concentration / (2 * a.element_count),
      diagram.concentration / (2 * b.element_count)
  end
  fail("invalid boundary convention")
end

-- At their mutual existence limit, both solids have unit activity. No amount
-- balance, diagram concentration or aqueous boundary convention enters here.
function M.solid_boundary_activities(diagram, first, second)
  local a = diagram.species_by_id[M.parse_species(first, diagram.element).id]
  local b = diagram.species_by_id[M.parse_species(second, diagram.element).id]
  if not a or not b or a.id == b.id or
    a.phase ~= "solid" or b.phase ~= "solid" then
    fail("solid boundary requires two distinct declared solid species")
  end
  return 1, 1
end

-- Compute in log space: tiny positive concentrations need never be divided.
function M.calculate(diagram)
  if not (diagram.thermodynamics and diagram.thermodynamics.checked) then
    fail("calculate requires a checked diagram; run pourbaix/check first")
  end
  if diagram.activity_model ~= "ideal" then
    fail("calculate requires an explicit activity model=ideal in the declaration")
  end
  local result = equations.calculate(copy(diagram), function(d, boundary)
    local a, b = d.species_by_id[boundary.first], d.species_by_id[boundary.second]
    local values = {}
    for _, species in ipairs({a, b}) do
      if species.phase == "solid" then
        values[species.id] = 0
      else
        local divisor = species.element_count
        if a.phase == "aqueous" and b.phase == "aqueous" then
          divisor = d.boundary_convention == "equal concentrations"
            and (a.element_count + b.element_count) or (2 * species.element_count)
        end
        values[species.id] = (math.log(d.concentration) - math.log(divisor)) / math.log(10)
      end
    end
    return values
  end)
  result.calculation = {calculated = true, activity_model = "ideal",
    standard_concentration = 1, concentration_unit = "mol/L"}
  return result
end

-- A selection never mutates calculated equations or earlier snapshots.
function M.select(diagram, options)
  return selection.select(copy(diagram), options)
end

-- Handles outlive aliases and TeX groups. Copies protect stored snapshots.
function M.new_registry()
  local records = {}
  return {
    build = function(raw, options)
      local diagram = M.select(M.calculate(M.check(M.declare(raw))), options)
      records[#records + 1] = diagram
      return #records, copy(diagram)
    end,
    add = function(raw)
      local diagram = M.declare(raw)
      records[#records + 1] = diagram
      return #records, copy(diagram)
    end,
    get = function(handle)
      local record = records[tonumber(handle)]
      if not record then
        fail("unknown diagram handle: " .. tostring(handle))
      end
      return copy(record)
    end,
    select = function(handle, options)
      local record = records[tonumber(handle)]
      if not record then fail("unknown diagram handle: " .. tostring(handle)) end
      local parsed = selection.options(options)
      if record.selection and record.selection.ph_min == parsed.ph_min and
          record.selection.ph_max == parsed.ph_max and record.selection.ph_step == parsed.ph_step then
        return tonumber(handle), copy(record)
      end
      local selected = M.select(record, options)
      records[#records+1] = selected
      return #records, copy(selected)
    end,
    calculate = function(handle)
      local record = records[tonumber(handle)]
      if not record then fail("unknown diagram handle: " .. tostring(handle)) end
      if record.calculation then return tonumber(handle), copy(record) end
      local calculated = M.calculate(record)
      records[#records + 1] = calculated
      return #records, copy(calculated)
    end,
    check = function(handle)
      local record = records[tonumber(handle)]
      if not record then fail("unknown diagram handle: " .. tostring(handle)) end
      if record.thermodynamics and record.thermodynamics.checked then
        return tonumber(handle), copy(record)
      end
      local checked = M.check(record)
      records[#records + 1] = checked
      return #records, copy(checked)
    end,
  }
end

return M
