-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Classical species inventories with independent analytic checks.
package.path=assert(arg[1]):match('^(.*[/\\])')..'?.lua;'..package.path
local core=dofile(arg[1])
local systems={
 Cu='Cu(s),Cu^2+,Cu2O(s),Cu(OH)2(s)',
 Zn='Zn(s),Zn^2+,Zn(OH)2(s),ZnO2^2-',
 Al='Al(s),Al^3+,Al(OH)3(s),Al(OH)4^-',
 Ag='Ag(s),Ag^+,Ag2O(s)',
 Pb='Pb(s),Pb^2+,Pb(OH)2(s),HPbO2^-',
 Ni='Ni(s),Ni^2+,Ni(OH)2(s)',
 Cr='Cr(s),Cr^3+,Cr(OH)3(s),Cr2O7^2-,CrO4^2-',
 Mn='Mn(s),Mn^2+,Mn(OH)2(s),MnO2(s),MnO4^-',
 Cl='Cl^-,Cl2(aq),HClO(aq),ClO^-'}
local function near(a,b) assert(math.abs(a-b)<1e-9,tostring(a)..' != '..tostring(b)) end
local checked_intersections=0
for element,species in pairs(systems) do
 local d=core.calculate(core.check(core.declare{element=element,species=species,
  temperature=298.15,concentration=.01,boundary_convention='equal element concentrations',constants={}}))
 local selected=core.select(d,{ph_min=0,ph_max=element=='Pb' and 20 or 16})
 assert(#selected.species==#d.species)
 assert(#d.boundaries==#d.species*(#d.species-1)/2)
 assert(#selected.selection.segments>0)
 for _,q in ipairs(d.boundaries) do
  local f,s=q.first,q.second
  -- Reaction balance yields these independent acid/base intersections.
  local function ispair(a,b)
   local matches=(f==a and s==b) or (f==b and s==a)
   if matches then checked_intersections=checked_intersections+1 end
   return matches
  end
  if ispair('Ni^2+','Ni(OH)2(s)') then near(q.equation.ph,(12.794+2)/2) end
  if ispair('Ag^+','Ag2O(s)') then near(q.equation.ph,(12.574+4)/2) end
  if ispair('HClO(aq)','ClO^-') then near(q.equation.ph,7.5692) end
  if ispair('Zn(OH)2(s)','ZnO2^2-') then near(q.equation.ph,13.85) end
  if ispair('Pb(OH)2(s)','HPbO2^-') then near(q.equation.ph,17.91) end
  if ispair('Al(OH)3(s)','Al(OH)4^-') then near(q.equation.ph,12.59) end
  if ispair('Cr2O7^2-','CrO4^2-') then near(q.equation.ph,6.28) end
 end
 print('PASS gallery '..element..': '..#selected.selection.segments..' retained segments')
end

assert(checked_intersections==7)
