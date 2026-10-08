-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

package.path=assert(arg[1]):match('^(.*[/\\])')..'?.lua;'..package.path
local core=dofile(arg[1])
local function near(a,b) assert(math.abs(a-b)<1e-8,tostring(a)..' != '..tostring(b)) end
local function potential(a,b,v) return {kind='standard potential',oxidized=a,reduced=b,value=v} end
local function solubility(a,v) return {kind='solubility product',solid=a,log_value=v} end
local function diagram(element,species,ct,convention,constants,database)
 return core.select(core.calculate(core.check(core.declare{
  element=element,species=species,concentration=ct,temperature=298.15,
  boundary_convention=convention,constants=constants,thermodynamic_database=database})),
  {ph_min=0,ph_max=14})
end
local function equation(d,a,b)
 for _,q in ipairs(d.boundaries) do
  if (q.first==a and q.second==b) or (q.first==b and q.second==a) then return q.equation end
 end
 error('Missing pair '..a..' / '..b)
end
local s=math.log(10)*1.380649e-23/1.602176634e-19*298.15
local fe=diagram('Fe','Fe(s),Fe^2+,Fe^3+,Fe(OH)2(s),Fe(OH)3(s)',.01,
 'equal element concentrations',{})
near(equation(fe,'Fe(s)','Fe^2+').b,-.440-s)
near(equation(fe,'Fe^2+','Fe^3+').b,.771)
near(equation(fe,'Fe^3+','Fe(OH)3(s)').ph,2.297)
-- Independent Nernst expressions, with the limiting atom balance for iodine.
for _,convention in ipairs{'equal concentrations','equal element concentrations'} do
 local d=diagram('I','IO3^-,I^-,I2(aq)',.001,convention,{
  potential('I2(aq)','I^-',.620),potential('IO3^-','I^-',1.0972309)},'none')
 local ci,cj=.001/3,.001/3
 if convention=='equal element concentrations' then ci,cj=.001/4,.001/2 end
 local lower=.620+s/2*math.log(ci/cj^2,10)
 local upper=(6*1.0972309-.620)/5-s/10*math.log(ci/cj^2,10)
 near(equation(d,'I2(aq)','I^-').b,lower)
 near(equation(d,'I2(aq)','IO3^-').b,upper)
 local crossing=(upper-lower)/(1.2*s)
 local last=0
 for _,v in ipairs(d.selection.domains) do
  if d.species[v.species].id=='I2(aq)' then last=math.max(last,v.ph_max) end
 end
 near(last,crossing)
 near(equation(d,'IO3^-','I^-').a,-s)
 near(equation(d,'IO3^-','I^-').b,1.0972309)
end
local u=diagram('U','U(s),U^4+,U^3+,UO2^2+,U(OH)3(s),U(OH)4(s),UO2(OH)2(s)',1,
 'equal element concentrations',{
 potential('U^4+','U(s)',-1.51),potential('U^4+','U^3+',-.61),
 potential('UO2^2+','U^4+',.33),solubility('U(OH)3(s)',-18.5),
 solubility('U(OH)4(s)',-49),
 {kind='equilibrium constant',first='UO2(OH)2(s)',second='UO2^2+',log_value=4},
 {kind='water ion product',log_value=-14}},'none')
assert(#u.boundaries==21)
near(equation(u,'U(s)','U^3+').b,-1.81)
near(equation(u,'U^4+','U(OH)4(s)').ph,14-49/4)
near(equation(u,'UO2^2+','UO2(OH)2(s)').ph,14-24/2)
for _,v in ipairs(u.selection.domains) do assert(u.species[v.species].id~='U(OH)3(s)') end
print('Tutorial analytic checks passed')

-- A combined build commits exactly one record, and no record on failure.
local registry=core.new_registry()
local raw={element='Fe',species='Fe(s),Fe^2+',temperature=298.15,
 concentration=.01,boundary_convention='equal concentrations',constants={}}
local h,d=registry.build(raw,{ph_min=0,ph_max=14})
assert(h==1 and d.selection and d.calculation and d.thermodynamics.checked)
assert(not pcall(registry.build,raw,{ph_min=14,ph_max=0}))
raw.thermodynamic_database='none'
assert(not pcall(registry.build,raw,{ph_min=0,ph_max=14}))
raw.thermodynamic_database='aqueous-298'
assert(registry.build(raw,{ph_min=0,ph_max=14})==2)
d.selection.ph_min=99
assert(registry.get(h).selection.ph_min==0)

-- Rounded Nernst factors must also govern mixed E0/log K closure.
local rounded={element='Fe',species='Fe(s),Fe^2+,Fe(OH)2(s)',temperature=298.15,
 concentration=.01,boundary_convention='equal concentrations',nernst_factor=.06,
 thermodynamic_database='none',constants={potential('Fe^2+','Fe(s)',-.44),
 solubility('Fe(OH)2(s)',-16),{kind='water ion product',log_value=-14},
 potential('Fe(OH)2(s)','Fe(s)',-.08)}}
local h,r=registry.build(rounded,{ph_min=0,ph_max=14})
near(r.nernst_factor,.06)
near(equation(r,'Fe(s)','Fe^2+').b,-.5)
near(equation(r,'Fe(s)','Fe(OH)2(s)').a,-.06)
near(equation(r,'Fe(s)','Fe(OH)2(s)').b,-.08)
near(equation(r,'Fe^2+','Fe(OH)2(s)').ph,7)
rounded.nernst_factor='auto'
assert(not pcall(registry.build,rounded,{ph_min=0,ph_max=14}))
for _,value in ipairs{0,-.06,math.huge,'nan','0.06V','',false} do
 rounded.nernst_factor=value
 assert(not pcall(core.declare,rounded))
end
near(registry.get(h).nernst_factor,.06)
rounded.constants[4]=nil
rounded.nernst_factor='auto'
local automatic=core.declare(rounded)
near(automatic.nernst_factor,s)
assert(automatic.nernst_factor_source=='temperature')

-- The explicit uranyl dissolution reproduces every manual-conversion boundary.
local explicit=diagram('U','U(s),U^4+,U^3+,UO2^2+,U(OH)3(s),U(OH)4(s),UO2(OH)2(s)',1,
 'equal element concentrations',{
 potential('U^4+','U(s)',-1.51),potential('U^4+','U^3+',-.61),
 potential('UO2^2+','U^4+',.33),solubility('U(OH)3(s)',-18.5),
 solubility('U(OH)4(s)',-49),
 {kind='solubility product',solid='UO2(OH)2(s)',log_value=-24,
 reaction='UO2(OH)2(s) = UO2^2+ + 2 OH^-'},
 {kind='water ion product',log_value=-14}},'none')
for i,b in ipairs(u.boundaries) do
 local e=explicit.boundaries[i].equation
 assert(e.kind==b.equation.kind)
 for _,field in ipairs({'a','b','ph'}) do
  if e[field] then near(e[field],b.equation[field]) end
 end
end
assert(#explicit.selection.segments==#u.selection.segments)
for i,segment in ipairs(u.selection.segments) do
 local other=explicit.selection.segments[i]
 assert(other.name==segment.name)
end
