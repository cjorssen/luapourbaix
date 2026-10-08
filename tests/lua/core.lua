-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- texlua may expose engine tables even in script mode. Remove them to enforce
-- the core's independence rather than relying on the host's initial globals.
tex, token, node, kpse, resolvers = nil, nil, nil, nil, nil
local before = {}
for key in pairs(_G) do
  before[key] = true
end
package.path = assert(arg[1]):match("^(.*[/\\])") .. "?.lua;" .. package.path
local core = dofile(assert(arg[1], "core path is required"))
assert(type(core) == "table", "core must return a module table")
assert(type(core.version) == "string", "missing version")
for key in pairs(_G) do
  assert(before[key], "core leaked global: " .. key)
end
assert(tex == nil, "core test must run outside the typesetting engine")
local function rejects(f, expected)
  local ok, message = pcall(f)
  assert(not ok and tostring(message):find(expected, 1, true), tostring(message))
end
local function iron()
  return {
    name = "Fe1E-2", element = "Fe", temperature = 298.15, concentration = "1E-2",
    species = "Fe(s),Fe^2+,Fe^3+,Fe(OH)2(s),Fe(OH)3(s)",
    boundary_convention = "equal concentrations",
    constants = {
      { kind = "standard potential", oxidized = "Fe^3+", reduced = "Fe^2+", value = ".77" },
      { kind = "standard potential", oxidized = "Fe^2+", reduced = "Fe(s)", value = "-.44" },
      { kind = "solubility product", solid = "Fe(OH)2(s)", value = "1e-15" },
      { kind = "solubility product", solid = "Fe(OH)3(s)", value = "1e-38" },
    },
  }
end
local d = core.declare(iron())
assert(d.concentration == .01 and #d.species == 5 and #d.constants == 4)
assert(d.species[4].composition.O == 2 and d.species[5].composition.H == 3)
assert(d.constants[1].unit == "V" and d.constants[3].unit == "1")
assert(d.temperature == 298.15 and d.temperature_unit == "K")
assert(#d.oxidation_groups == 3)
assert(d.oxidation_groups[1].oxidation_number == 0)
assert(d.oxidation_groups[2].oxidation_number == 2)
assert(d.oxidation_groups[3].oxidation_number == 3)
assert(d.oxidation_groups[2].species[1].id == "Fe^2+")
assert(d.oxidation_groups[2].species[2].id == "Fe(OH)2(s)")
assert(#d.boundaries == 10 and d.boundaries_by_name["8-temp"].law == "Nernst")
assert(d.boundaries_by_name["a-temp"].first == "Fe^2+")
assert(d.boundaries_by_name["b-temp"].second == "Fe(OH)3(s)")
for _, boundary in ipairs(d.boundaries) do
  assert(boundary.provisional and boundary.slope == nil and boundary.coordinates == nil)
end
assert(core.parse_species("Fe^{2+}(aq)", "Fe").id == "Fe^2+")
assert(core.parse_species("Fe2(SO4)3(s)", "Fe").composition.O == 12)
assert(core.parse_species("Fe((OH)2)3(s)", "Fe").composition.O == 6)
local a, b = core.aqueous_boundary_concentrations(d, "Fe^2+", "Fe^3+")
assert(a == .005 and b == .005)

-- Independent element balance with unequal atom counts (2 and 1).
local chromium = {
  element = "Cr", temperature = 298.15, species = { "Cr2O7^2-", "Cr^3+" }, constants = {},
  concentration = .012, boundary_convention = "equal concentrations",
}
a, b = core.aqueous_boundary_concentrations(core.declare(chromium), "Cr2O7^2-", "Cr^3+")
assert(a == .004 and b == .004 and 2 * a + b == .012)
chromium.boundary_convention = "equal element concentrations"
a, b = core.aqueous_boundary_concentrations(core.declare(chromium), "Cr2O7^2-", "Cr^3+")
assert(a == .003 and b == .006 and 2 * a == b and 2 * a + b == .012)
rejects(function() core.aqueous_boundary_concentrations(d, "Fe(s)", "Fe^2+") end,
  "two distinct declared aqueous species")

-- Solid activities must not inherit aqueous concentration assignments, even
-- for unequal element counts, reversed arguments or different concentrations.
for _, convention in ipairs({ "equal concentrations", "equal element concentrations" }) do
  for _, concentration in ipairs({ 1e-8, 1e-2, 1 }) do
    local solids = core.declare({
      element = "Fe", temperature = 298.15, species = { "Fe(s)", "Fe2O3(s)", "Fe^2+" },
      constants = {}, concentration = concentration, boundary_convention = convention,
    })
    for _, pair in ipairs({ { "Fe(s)", "Fe2O3(s)" }, { "Fe2O3(s)", "Fe(s)" } }) do
      a, b = core.solid_boundary_activities(solids, pair[1], pair[2])
      assert(a == 1 and b == 1)
    end
    assert(solids.species_by_id["Fe^2+"].concentration == nil)
    assert(solids.species_by_id["Fe(s)"].concentration == nil)
    assert(solids.species_by_id["Fe2O3(s)"].concentration == nil)
  end
end
for _, pair in ipairs({
  { "Fe(s)", "Fe^2+" }, { "Fe(s)", "Fe(s)" }, { "Fe(s)", "Fe2O3(s)" },
}) do
  rejects(function() core.solid_boundary_activities(d, pair[1], pair[2]) end,
    "two distinct declared solid species")
end

local invalid = {
  { "element", "Iron", "element symbol" },
  { "name", 'Fe\");error("injection")', "name must" },
  { "species", "Fe^2+,Cr^3+", "does not contain" },
  { "species", "Fe^2+,Fe^{2+}(aq)", "duplicate species" },
  { "species", "Fe^2+,,Fe^3+", "empty entry" },
  { "species", "Fe(OH(s)", "unclosed group" },
  { "species", "Fe0(s)", "invalid stoichiometric" },
  { "species", "(Fe9007199254740991)9007199254740991(s)", "count is too large" },
  { "species", "Fe^0+", "invalid charge" },
  { "species", "Fe^2+(s)", "electrically neutral" },
  { "species", "Fe", "require (aq) or (s)" },
  { "species", "Fe^2+;error()", "require (aq) or (s)" },
  { "concentration", "0", "positive" },
  { "concentration", "-1", "positive" },
  { "concentration", "1e999", "finite" },
  { "concentration", "1e-999", "positive" },
  { "concentration", "0x10", "decimal number" },
  { "concentration", "1/100", "decimal number" },
  { "concentration", "1e-2 mol/L", "decimal number" },
  { "concentration", math.huge, "finite" },
  { "concentration", 0/0, "finite" },
  { "temperature", "", "decimal number" },
  { "temperature", "0", "positive" },
  { "thermodynamic_tolerance", "0", "positive" },
  { "thermodynamic_tolerance", math.huge, "finite" },
  { "temperature", "-1", "positive" },
  { "temperature", "25 C", "decimal number" },
  { "temperature", math.huge, "finite" },
  { "boundary_convention", "", "explicitly" },
  { "boundary_convention", "equal", "explicitly" },
}
for _, case in ipairs(invalid) do
  local raw = iron()
  raw[case[1]] = case[2]
  rejects(function() core.declare(raw) end, case[3])
end
rejects(function()
  local raw = iron(); raw.constants = nil; core.declare(raw)
end, "constants must be supplied")
rejects(function()
  local raw = iron(); raw.constants[1].reduced = "Fe^+"; core.declare(raw)
end, "undeclared species")
rejects(function()
  local raw = iron(); raw.constants[3].solid = "Fe^2+"; core.declare(raw)
end, "requires a solid")
rejects(function()
  local raw = iron(); raw.constants[3].value = 0; core.declare(raw)
end, "positive")
rejects(function()
  local raw = iron(); raw.constants[2] = raw.constants[1]; core.declare(raw)
end, "duplicate thermodynamic")
rejects(function()
  local raw = iron(); raw.constants = { [2] = raw.constants[1] }; core.declare(raw)
end, "dense array")
rejects(function()
  local raw = iron(); raw.species = { extra = "Fe(s)" }; core.declare(raw)
end, "dense array")

local function minimal(species, element)
  return { element = element or "Fe", species = species, constants = {},
    concentration = .01, temperature = 298.15, boundary_convention = "equal concentrations" }
end
rejects(function()
  local raw = iron(); raw.temperature = nil; core.declare(raw)
end, "temperature (K)")
rejects(function() core.declare(minimal("Fe3O4(s)")) end, "explicit oxidation number required")
local mixed = minimal("Fe3O4(s)")
mixed.species_data = { { species = "Fe3O4(s)", oxidation_number = "8/3" } }
assert(core.declare(mixed).species[1].oxidation_number == 8/3)
assert(core.declare(mixed).species[1].oxidation_basis == "explicit")
mixed.species_data[1].oxidation_number = "8/0"
rejects(function() core.declare(mixed) end, "positive")

local complex = minimal("Fe^2+,Fe(CN)6^4-")
rejects(function() core.declare(complex) end, "explicit oxidation number required")
complex.species_data = { { species = "Fe(CN)6^4-", oxidation_number = 2 } }
rejects(function() core.declare(complex) end, "explicit acidity ranks required")
complex.species_data[1].acidity_rank = 2
rejects(function() core.declare(complex) end, "cover every species")
complex.species_data[2] = { species = "Fe^2+", acidity_rank = 1 }
local ordered = core.declare(complex)
assert(ordered.ordered_species[1].id == "Fe^2+")
assert(ordered.oxidation_groups[1].acidity_basis == "explicit ranks")
assert(ordered.ordered_species[2].acidity_index == nil)
complex.species_data[2].acidity_rank = 2
rejects(function() core.declare(complex) end, "duplicate acidity rank")

-- A real stoichiometric tie must not be disguised as a strict acidity order.
local tied = core.declare(minimal("FeO(s),Fe(OH)2(s)"))
assert(tied.species[1].acidity_index == tied.species[2].acidity_index)
assert(#tied.boundaries == 1 and tied.boundaries[1].kind == "vertical")
local dichromate = core.declare(minimal("CrO4^2-,Cr2O7^2-", "Cr"))
assert(dichromate.ordered_species[1].id == "Cr2O7^2-")
assert(dichromate.ordered_species[1].oxidation_number == 6)

-- Enumeration is independent of declaration order and includes non-neighbours.
local reverse = iron()
reverse.species = "Fe(OH)3(s),Fe(OH)2(s),Fe^3+,Fe^2+,Fe(s)"
local reverse_d = core.declare(reverse)
for i, boundary in ipairs(d.boundaries) do
  local other = reverse_d.boundaries[i]
  assert(boundary.name == other.name and boundary.first == other.first and boundary.second == other.second)
end
local custom = iron()
custom.boundary_labels = { vertical_prefix = "v-", redox_prefix = "r-", suffix = "-trial" }
custom.boundary_names = { { first = "Fe(OH)2(s)", second = "Fe^2+", name = "precip-II" } }
local named = core.declare(custom)
assert(named.boundaries_by_name["precip-II"].kind == "vertical")
assert(named.boundaries_by_name["r-1-trial"] and named.boundaries_by_name["v-b-trial"])
custom.boundary_names[1].name = "r-1-trial"
rejects(function() core.declare(custom) end, "duplicate boundary name")
custom.boundary_names[1].name = "bad\\name"
rejects(function() core.declare(custom) end, "invalid boundary name")
custom.boundary_names[1].name = "test"
custom.boundary_names[1].first = "FeO(s)"
rejects(function() core.declare(custom) end, "undeclared species")
local reversed_potential = iron()
reversed_potential.constants[1].oxidized, reversed_potential.constants[1].reduced = "Fe^2+", "Fe^3+"
rejects(function() core.declare(reversed_potential) end, "oxidized oxidation number >")

-- Artificial formula series tests alphabetic numbering past z, not stability.
local many = { "Fe^2+", "Fe(OH)^+", "Fe(OH)2(aq)" }
for n = 3, 8 do many[#many + 1] = "Fe(OH)" .. n .. "^" .. (n - 2) .. "-" end
local all = core.declare(minimal(many))
assert(#all.boundaries == 36 and all.boundaries_by_name["z-temp"])
assert(all.boundaries_by_name["aa-temp"] and all.boundaries_by_name["aj-temp"])

local registry = core.new_registry()
local raw = iron()
local handle, returned = registry.add(raw)
raw.constants[1].value = 99
returned.species[1].composition.Fe = 99
local saved = registry.get(handle)
assert(saved.constants[1].value == .77 and saved.species[1].composition.Fe == 1)
assert(saved.species[1] == saved.species_by_id["Fe(s)"], "copy lost lookup identity")
saved.concentration = 99
assert(registry.get(handle).concentration == .01)
rejects(function()
  local bad = iron(); bad.concentration = -1; registry.add(bad)
end, "positive")
assert(registry.add(iron()) == handle + 1, "failed transaction allocated a handle")
rejects(function() registry.get(99999) end, "unknown diagram handle")
for key in pairs(_G) do
  assert(before[key], "core operation leaked global: " .. key)
end
print("PASS: formulas, declarations, conventions, validation and snapshot isolation")
