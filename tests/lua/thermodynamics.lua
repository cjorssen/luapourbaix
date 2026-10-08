-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Independent thermochemical identities, not fitted boundary coordinates.
package.path = assert(arg[1]):match("^(.*[/\\])") .. "?.lua;" .. package.path
local core = dofile(arg[1])
assert(require("luapourbaix").version == core.version)
local function near(a, b)
  assert(math.abs(a - b) < 1e-10 * math.max(1, math.abs(b)), tostring(a) .. " != " .. b)
end
local function rejects(callback, expected)
  local ok, message = pcall(callback)
  assert(not ok and tostring(message):find(expected, 1, true), tostring(message))
end
local function iron()
  return { element = "Fe", species = "Fe(s),Fe^2+,Fe^3+,Fe(OH)2(s),Fe(OH)3(s)",
    temperature = 298.15, concentration = .01, boundary_convention = "equal concentrations",
    constants = {
      { kind = "standard potential", oxidized = "Fe^3+", reduced = "Fe^2+", value = .77 },
      { kind = "standard potential", oxidized = "Fe^2+", reduced = "Fe(s)", value = -.44 },
      { kind = "solubility product", solid = "Fe(OH)2(s)", value = 1e-15 },
      { kind = "solubility product", solid = "Fe(OH)3(s)", value = 1e-38 },
    } }
end
local raw = iron()
local prepared = core.declare(raw)
local checked = core.check(prepared)
assert(not prepared.thermodynamics and not prepared.boundaries[1].thermodynamics)
assert(checked.thermodynamics.checked)
assert(checked.thermodynamics.water.status == "default")
near(checked.thermodynamics.water.log_k, -14)
near(checked.boundaries_by_name["3-temp"].thermodynamics.standard_potential, (.77 + 2 * -.44) / 3)
near(checked.boundaries_by_name["a-temp"].thermodynamics.log_k, -13)
near(checked.boundaries_by_name["b-temp"].thermodynamics.log_k, -4)
local factor = 8.31446261815324 * 298.15 * math.log(10) / 96485.3321233100184
near(checked.boundaries_by_name["8-temp"].thermodynamics.standard_potential, .77 - 9 * factor)
for _, boundary in ipairs(checked.boundaries) do
  local data = assert(boundary.thermodynamics)
  assert(#data.sources > 0)
  assert(not boundary.slope and not boundary.coordinates)
  -- Verify the provenance against the actual input log constants.
  local value, coefficients = 0, {}
  for _, source in ipairs(data.sources) do
    local input = checked.thermodynamics.inputs[source.index]
    value = value + source.coefficient * input.value
    for key, coefficient in pairs(input.coefficients) do
      coefficients[key] = (coefficients[key] or 0) + source.coefficient * coefficient
    end
  end
  near(value, data.log_k)
  for key, coefficient in pairs(data.reaction.coefficients) do
    near(coefficients[key] or 0, coefficient)
    coefficients[key] = nil
  end
  for _, coefficient in pairs(coefficients) do near(coefficient, 0) end
end
-- Concentrations, convention and input order do not change standard constants.
raw.concentration, raw.boundary_convention = 1e-8, "equal element concentrations"
raw.constants[1], raw.constants[4] = raw.constants[4], raw.constants[1]
local permuted = core.check(core.declare(raw))
for i, boundary in ipairs(checked.boundaries) do
  near(permuted.boundaries[i].thermodynamics.log_k, boundary.thermodynamics.log_k)
end
-- A supplied hydrolysis constant and Ks determine Kw, even at 298.15 K:
-- the inferred value takes priority over the fallback approximation.
raw = iron()
raw.constants[5] = { kind = "equilibrium constant", first = "Fe^2+",
  second = "Fe(OH)2(s)", log_value = -12 }
checked = core.check(core.declare(raw))
near(checked.thermodynamics.water.log_k, -13.5)
assert(checked.thermodynamics.water.status == "derived")
raw.temperature = 310
checked = core.check(core.declare(raw))
near(checked.thermodynamics.water.log_k, -13.5)
raw.constants[5] = nil
rejects(function() core.check(core.declare(raw)) end, "Water ion product")
raw.constants[5] = { kind = "water ion product", log_value = -13.5 }
checked = core.check(core.declare(raw))
near(checked.boundaries_by_name["a-temp"].thermodynamics.log_k, -12)
assert(checked.thermodynamics.water.status == "provided")
-- Derive a missing Ks from an acid-form constant and water data.
raw.constants[3] = { kind = "equilibrium constant", first = "Fe^2+",
  second = "Fe(OH)2(s)", log_value = -12 }
checked = core.check(core.declare(raw))
near(checked.thermodynamics.solubilities["Fe(OH)2(s)"].log_k, -15)
assert(checked.thermodynamics.solubilities["Fe(OH)2(s)"].status == "derived")
-- Detect inconsistent cycles, including conflicting explicit water data.
raw = iron()
raw.constants[5] = { kind = "standard potential", oxidized = "Fe^3+", reduced = "Fe(s)", value = 0 }
rejects(function() core.check(core.declare(raw)) end, "inconsistent thermodynamic cycle")
raw.constants[5].value = (.77 - .88) / 3
core.check(core.declare(raw))
raw.constants[5] = { kind = "equilibrium constant", first = "Fe^2+", second = "Fe(OH)2(s)", log_value = -12 }
raw.constants[6] = { kind = "water ion product", value = 1e-14 }
rejects(function() core.check(core.declare(raw)) end, "inconsistent thermodynamic cycle")
-- Missing data must identify each affected pair by its provisional name.
raw = iron(); raw.constants = {}; raw.thermodynamic_database = "none"
rejects(function() core.check(core.declare(raw)) end, "1-temp [Fe^2+ -> Fe(s)]")
rejects(function() core.check(core.declare(raw)) end, "a-temp [Fe^2+ -> Fe(OH)2(s)]")
-- No water input is needed for simple redox pairs at other temperatures.
raw.species, raw.temperature = "Fe(s),Fe^2+,Fe^3+", 310
raw.constants = { iron().constants[1], iron().constants[2] }
checked = core.check(core.declare(raw))
assert(not checked.thermodynamics.water)
near(checked.boundaries_by_name["2-temp"].thermodynamics.standard_potential, (.77 - .88) / 3)
-- Primitive balancing with unequal element counts (dichromate reduction).
raw = { element = "Cr", temperature = 298.15, concentration = .01,
  boundary_convention = "equal element concentrations", species = "Cr2O7^2-,Cr^3+",
  constants = { { kind = "standard potential", oxidized = "Cr2O7^2-", reduced = "Cr^3+", value = 1.33 } } }
checked = core.check(core.declare(raw))
local reaction = checked.boundaries[1].thermodynamics.reaction
assert(reaction.coefficients["Cr2O7^2-"] == -1 and reaction.coefficients["Cr^3+"] == 2)
assert(reaction.coefficients["H^+"] == -14 and reaction.coefficients["H2O(l)"] == 7)
assert(reaction.electrons == 6)
near(checked.boundaries[1].thermodynamics.standard_potential, 1.33)
-- Logarithmic input/output survives unrepresentable K without clipping.
raw.species = "Cr2O7^2-,CrO4^2-"
raw.constants = { { kind = "equilibrium constant", first = "Cr2O7^2-", second = "CrO4^2-", log_value = 1000 } }
checked = core.check(core.declare(raw))
near(checked.boundaries[1].thermodynamics.log_k, 1000)
assert(not checked.boundaries[1].thermodynamics.equilibrium_constant)
raw.constants[1].first, raw.constants[1].second = "CrO4^2-", "Cr2O7^2-"
raw.constants[1].log_value = -1000
checked = core.check(core.declare(raw))
near(checked.boundaries[1].thermodynamics.log_k, 1000)
raw.constants[1].value = 1
rejects(function() core.declare(raw) end, "exactly one")
-- Water and a free ion cancel: neither needs to become a domain or be
-- supplied numerically at 310 K for this hydration-independent reaction.
raw = { element = "Fe", temperature = 310, concentration = .01,
  boundary_convention = "equal concentrations", species = "Fe(OH)2(s),Fe2(OH)4(s)",
  constants = {
    { kind = "solubility product", solid = "Fe(OH)2(s)", log_value = -15 },
    { kind = "solubility product", solid = "Fe2(OH)4(s)", log_value = -30 },
  } }
checked = core.check(core.declare(raw))
assert(#checked.species == 2 and checked.species_by_id["Fe^2+"] == nil)
assert(checked.thermodynamics.water == nil)
near(checked.boundaries[1].thermodynamics.log_k, 0)
-- Explicit ranks do not supply missing ligand reaction participants.
raw = { element = "Fe", temperature = 298.15, concentration = .01,
  boundary_convention = "equal concentrations", species = "Fe^2+,Fe(CN)6^4-", constants = {},
  species_data = { { species = "Fe^2+", acidity_rank = 1 },
    { species = "Fe(CN)6^4-", oxidation_number = 2, acidity_rank = 2 } } }
rejects(function() core.check(core.declare(raw)) end, "additional reaction participants")
-- Failure atomicity and immutable preparation handles.
local registry = core.new_registry()
local initial = registry.add(iron())
local new, result = registry.check(initial)
assert(new == initial + 1 and result.thermodynamics.checked)
assert(not registry.get(initial).thermodynamics)
assert(registry.check(new) == new)
raw = iron(); raw.constants = {}; raw.thermodynamic_database = "none"
local incomplete = registry.add(raw)
rejects(function() registry.check(incomplete) end, "insufficient thermodynamic data")
assert(registry.add(iron()) == incomplete + 1)
print("PASS: thermodynamic closure, balancing, provenance, missing data and transactions")

-- Explicit uranyl dissolution: preserve source K, derive the acid reaction.
local uranyl={element='U',species='UO2(OH)2(s),UO2^2+',temperature=298.15,
 concentration=1,boundary_convention='equal concentrations',thermodynamic_database='none',
 constants={{kind='solubility product',solid='UO2(OH)2(s)',log_value=-24,
 reaction='UO2(OH)2(s) = UO2^2+ + 2 HO^-'},
 {kind='water ion product',log_value=-14}}}
local function uranyl_check() return core.check(core.declare(uranyl)) end
local u=core.calculate(uranyl_check())
near(u.boundaries[1].thermodynamics.log_k,-4)
near(u.boundaries[1].equation.ph,2)
near(u.thermodynamics.solubilities['UO2(OH)2(s)'].log_k,-24)
assert(u.thermodynamics.inputs[1].coefficients['OH^-']==2)
assert(u.constants[1].reaction==uranyl.constants[1].reaction)
for _,case in ipairs({
 {'2 UO2(OH)2(s) = 2 UO2^2+ + 4 OH^-',-48},
 {'1/2 UO2(OH)2(s) = 1/2 UO2^2+ + OH^-',-12},
}) do
 uranyl.constants[1].reaction,uranyl.constants[1].log_value=case[1],case[2]
 near(uranyl_check().boundaries[1].thermodynamics.log_k,-4)
end
uranyl.constants[1]={kind='equilibrium constant',first='UO2(OH)2(s)',second='UO2^2+',
 reaction='UO2^2+ + 2 H2O(l) = UO2(OH)2(s) + 2 H^+',log_value=-4}
near(uranyl_check().boundaries[1].thermodynamics.log_k,-4)
local valid=uranyl.constants[1].reaction
for _,case in ipairs({
 {'','requires exactly one'},
 {'UO2(OH)2(s) = UO2^2+ + OH^-','unbalanced for element'},
 {'UO2(OH)2(s) = UO2^+ + 2 OH^-','electric charge'},
 {'UO2(OH)2(s) = UO2^2++2 OH^-','reaction side'},
 {'UO2(OH)2(s) = UO2^2+ + 2 OH^- + e^-','electrons'},
 {'UO2(OH)2(s) = UO2^2+ = 2 OH^-','exactly one'},
 {'0 UO2(OH)2(s) = UO2^2+','positive integers'},
 {'1/0 UO2(OH)2(s) = UO2^2+','positive integers'},
 {'UO2(OH)2(s) = UO2(OH)2(s)','empty net'},
 {'UO2(OH)2(s) = UO2^2+ + 2 OH^- + ','reaction side'},
}) do
 uranyl.constants[1].reaction=case[1]
 rejects(function() core.declare(uranyl) end,case[2])
end
uranyl.constants[1].reaction=valid
local registry=core.new_registry()
local handle=registry.add(uranyl)
uranyl.constants[1].reaction='invalid'
assert(not pcall(registry.add,uranyl))
assert(registry.get(handle).constants[1].reaction==valid)
uranyl.constants[1].reaction=valid
uranyl.constants[#uranyl.constants+1]={kind='solubility product',solid='UO2(OH)2(s)',
 reaction='UO2(OH)2(s) = UO2^2+ + 2 OH^-',log_value=-25}
rejects(uranyl_check,'inconsistent')
