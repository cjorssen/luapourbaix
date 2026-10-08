-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Analytic limiting-boundary values, degeneracy, and snapshot transactions.
package.path = assert(arg[1]):match("^(.*[/\\])") .. "?.lua;" .. package.path
local core = dofile(arg[1])
local function near(a,b) assert(math.abs(a-b)<1e-10, tostring(a).." != "..b) end
local function rejects(f, text)
  local ok, err = pcall(f)
  assert(not ok and tostring(err):find(text,1,true), tostring(err))
end
local function raw(species)
  return {element="Fe",species=species,temperature=298.15,concentration=.01,
    activity_model="ideal",boundary_convention="equal concentrations",
    thermodynamic_database="none",constants={}}
end
local d=raw("Fe(s),Fe^2+,Fe^3+,Fe(OH)2(s),Fe(OH)3(s)")
d.constants={
  {kind="standard potential",oxidized="Fe^3+",reduced="Fe^2+",value=.77},
  {kind="standard potential",oxidized="Fe^2+",reduced="Fe(s)",value=-.44},
  {kind="solubility product",solid="Fe(OH)2(s)",value=1e-15},
  {kind="solubility product",solid="Fe(OH)3(s)",value=1e-38}}
local reg=core.new_registry()
local first=reg.add(d)
rejects(function() reg.calculate(first) end,"checked diagram")
local checked=reg.check(first)
local handle, result=reg.calculate(checked)
assert(handle==3 and not reg.get(checked).calculation)
assert(reg.calculate(handle)==handle)
local factor=.059159349684781
local function equation(a,b)
  for _, boundary in ipairs(result.boundaries) do
    if (boundary.first==a and boundary.second==b) or
       (boundary.first==b and boundary.second==a) then return boundary.equation end
  end
  error("missing pair")
end
near(equation("Fe(s)","Fe^2+").b,-.44-factor)
near(equation("Fe^2+","Fe^3+").b,.77)
near(equation("Fe^2+","Fe(OH)2(s)").ph,7.5)
near(equation("Fe^3+","Fe(OH)3(s)").ph,2)
near(equation("Fe(OH)2(s)","Fe(OH)3(s)").a,-factor)
near(equation("Fe(OH)2(s)","Fe(OH)3(s)").b,.77-9*factor)
local old=equation("Fe(OH)2(s)","Fe(OH)3(s)").b
d.concentration=1e-300
result=core.calculate(core.check(core.declare(d)))
near(equation("Fe(OH)2(s)","Fe(OH)3(s)").b,old)
for _, b in ipairs(result.boundaries) do assert(b.equation) end
d.activity_model=nil
assert(core.calculate(core.check(core.declare(d))).calculation.activity_model=="ideal")
-- Same oxidation and hydration only: no proton term, no unique line.
local hydration=raw("FeO(s),Fe(OH)2(s)")
hydration.constants={{kind="equilibrium constant",first="FeO(s)",second="Fe(OH)2(s)",log_value=1}}
local h=core.calculate(core.check(core.declare(hydration)))
assert(h.boundaries[1].equation.kind=="empty" and not h.boundaries[1].equation.expression)
hydration.constants[1].log_value=0
h=core.calculate(core.check(core.declare(hydration)))
assert(h.boundaries[1].equation.kind=="identity")
-- Unequal atom counts: dichromate reduction consumes 14 protons / 6 electrons.
local cr=raw("Cr2O7^2-,Cr^3+");cr.element="Cr"
cr.constants={{kind="standard potential",oxidized="Cr2O7^2-",reduced="Cr^3+",value=1.33}}
local equal=core.calculate(core.check(core.declare(cr))).boundaries[1].equation
near(equal.a,-14*factor/6)
near(equal.b,1.33-factor/6*math.log(.01/3)/math.log(10))
cr.boundary_convention="equal element concentrations"
local weighted=core.calculate(core.check(core.declare(cr))).boundaries[1].equation
near(weighted.b,1.33-factor/6*math.log((.01/2)^2/(.01/4))/math.log(10))
assert(equal.b~=weighted.b)
print("PASS boundary equations")
