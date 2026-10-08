-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Sourced catalogue validation and end-to-end fallback behavior.
package.path = assert(arg[1]):match("^(.*[/\\])") .. "?.lua;" .. package.path
local core = dofile(arg[1])
local db = core.database
local function near(a, b)
  assert(math.abs(a - b) < 1e-9 * math.max(1, math.abs(b)), tostring(a) .. " != " .. b)
end
local function rejects(callback, expected)
  local ok, message = pcall(callback)
  assert(not ok and tostring(message):find(expected, 1, true), tostring(message))
end
local function raw(element, species)
  return { element = element, species = species, temperature = 298.15,
    concentration = .01, boundary_convention = "equal concentrations", constants = {} }
end
local function check(input) return core.check(core.declare(input)) end
local sources, counts, ids = db.sources(), {}, {}
local auxiliary = {
  ["e^-"] = { composition = {}, charge = -1 },
  ["H^+"] = { composition = { H = 1 }, charge = 1 },
  ["OH^-"] = { composition = { O = 1, H = 1 }, charge = -1 },
  ["H2O(l)"] = { composition = { H = 2, O = 1 }, charge = 0 },
}
for _, record in ipairs(db.list()) do
  assert(not ids[record.id]); ids[record.id] = true
  assert(record.temperature == 298.15 and record.solvent == "water")
  assert(sources[record.source] and record.locator and record.standard_state)
  assert(record.value or record.log_value)
  counts[record.kind] = (counts[record.kind] or 0) + 1
  local atoms, charge = {}, 0
  for id, coefficient in pairs(record.coefficients) do
    assert(coefficient % 1 == 0)
    local species = auxiliary[id] or core.parse_species(id, record.element)
    charge = charge + coefficient * species.charge
    for element, count in pairs(species.composition) do
      atoms[element] = (atoms[element] or 0) + coefficient * count
    end
  end
  near(charge, 0)
  for _, balance in pairs(atoms) do near(balance, 0) end
  if record.kind == "standard potential" then
    assert(-record.coefficients["e^-"] == record.electrons)
  elseif record.kind == "hydroxide formation" then
    near(record.log_value, record.source_log_value - record.hydroxide_count * record.source_water_log_k)
  elseif record.kind == "solubility product" then
    near(record.log_value, record.source_log_value + record.coefficients["OH^-"] * record.source_water_log_k)
  end
  -- Every record is usable for its own pair; phase overrides distinguish
  -- polymorphs. Earlier independent records may supersede a redundant value.
  local input = raw(record.element, { record.first, record.second })
  input.species_data = {}
  for id, phase in pairs(record.phases or {}) do
    input.species_data[#input.species_data + 1] = { species = id, thermodynamic_phase = phase }
  end
  local checked = check(input)
  assert(checked.thermodynamics.checked)
  assert(#checked.species == 2)
end
assert(counts["standard potential"] == 28)
assert(counts["acidity constant"] == 12)
assert(counts["equilibrium constant"] == 8)
assert(#db.list()==87)
assert(counts["hydroxide formation"] == 32)
assert(counts["solubility product"] == 7)
local retrieved = db.get("fe-iii-ii")
retrieved.value = 9
assert(db.get("fe-iii-ii").value == .771)
local list = db.list("Fe"); list[1].coefficients["Fe^3+"] = 99
assert(db.list("Fe")[1].coefficients["Fe^3+"] == -1)
rejects(function() db.get("missing") end, "unknown thermodynamic database entry")

-- Whole five-species iron diagram with no supplied numerical constants.
local iron = raw("Fe", "Fe(s),Fe^2+,Fe^3+,Fe(OH)2(s),Fe(OH)3(s)")
local checked = check(iron)
assert(#checked.boundaries == 10 and #checked.species == 5)
assert(#checked.constants == 0 and checked.thermodynamics.database_consulted)
assert(checked.thermodynamics.phases["Fe(OH)3(s)"] == "amorphous")
near(checked.boundaries_by_name["3-temp"].thermodynamics.standard_potential, (.771 - .88) / 3)
near(checked.thermodynamics.solubilities["Fe(OH)3(s)"].log_k, 4.891 - 42)
local factor = 8.31446261815324 * 298.15 * math.log(10) / 96485.3321233100184
near(checked.thermodynamics.solubilities["Fe(OH)2(s)"].log_k, 2 * (-.89 + .44) / factor)
for _, boundary in ipairs(checked.boundaries) do
  local log_k = 0
  for _, source in ipairs(boundary.thermodynamics.sources) do
    local input = checked.thermodynamics.inputs[source.index]
    if input.metadata.origin == "database" then assert(input.metadata.record.source) end
    log_k = log_k + source.coefficient * input.value
  end
  near(log_k, boundary.thermodynamics.log_k)
end

-- Supplied data and their linear consequences override fallback records.
iron.constants = { { kind = "standard potential", oxidized = "Fe^3+", reduced = "Fe^2+", value = .8 } }
checked = check(iron)
near(checked.boundaries_by_name["3-temp"].thermodynamics.standard_potential, (.8 - .88) / 3)
for _, input in ipairs(checked.thermodynamics.inputs) do
  assert(not input.metadata.record or input.metadata.record.id ~= "fe-iii-ii")
end
local complete = raw("Fe", "Fe^2+,Fe^3+")
complete.constants = iron.constants
checked = check(complete)
assert(not checked.thermodynamics.database_consulted)
near(checked.boundaries[1].thermodynamics.standard_potential, .8)

-- Phase selection changes Ks without changing the species domain set.
local aluminium = raw("Al", "Al^3+,Al(OH)3(s)")
checked = check(aluminium)
near(checked.thermodynamics.solubilities["Al(OH)3(s)"].log_k, -33.89)
aluminium.species_data = { { species = "Al(OH)3(s)", thermodynamic_phase = "amorphous" } }
checked = check(aluminium)
near(checked.thermodynamics.solubilities["Al(OH)3(s)"].log_k, -31.2)
aluminium.species_data[1].thermodynamic_phase = "bayerite"
rejects(function() check(aluminium) end, "Al(OH)3(s) = bayerite")

local metal_phase = raw("Fe", "Fe(s),Fe^2+")
metal_phase.species_data = { { species = "Fe(s)", thermodynamic_phase = "unavailable" } }
rejects(function() check(metal_phase) end, "Fe(s) = unavailable")

-- Acidity and cumulative hydroxide formation retain their distinct meanings.
checked = check(raw("P", "H3PO4(aq),H2PO4^-,HPO4^2-,PO4^3-"))
near(checked.boundaries_by_name["a-temp"].thermodynamics.pka, 2.168)
near(checked.boundaries_by_name["d-temp"].thermodynamics.pka, 7.207)
checked = check(raw("Zn", "Zn^2+,Zn(OH)4^2-"))
near(checked.thermodynamics.formations["Zn(OH)4^2-"].log_k, 14.8)
near(checked.boundaries[1].thermodynamics.log_k, -41.2)
assert(checked.boundaries[1].thermodynamics.pka == nil)
checked = check(raw("Fe", "FeOH^2+,Fe(OH)2^+"))
near(checked.boundaries[1].thermodynamics.pka, 3.48)
assert(#checked.species == 2 and not checked.species_by_id["Fe^3+"])
for _, input in ipairs(checked.thermodynamics.inputs) do
  assert(not input.coefficients["Fe(s)"])
end

-- No temperature extrapolation, and a reproducible opt-out.
iron.temperature = 310
rejects(function() check(iron) end, "Database aqueous-298 was searched at 310 K")
iron.temperature, iron.thermodynamic_database = 298.15, "none"
rejects(function() check(iron) end, "insufficient thermodynamic data")
iron.thermodynamic_database = "typo"
rejects(function() core.declare(iron) end, "thermodynamic database must")
print("PASS: 87 catalogue records, balances, fallback, phases, precedence and isolation")
