-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Independent redox examples, mesh events, acid selection and reconstruction.
package.path=assert(arg[1]):match("^(.*[/\\])").."?.lua;"..package.path
local core=dofile(arg[1])
local function near(a,b) assert(math.abs(a-b)<1e-10,tostring(a).." != "..tostring(b)) end
local function rejects(f,expected)
  local ok,err=pcall(f)
  assert(not ok and tostring(err):find(expected,1,true),tostring(err))
end
local function raw(element,species)
  return {element=element,species=species,temperature=298.15,concentration=.01,
    boundary_convention="equal concentrations",thermodynamic_database="none",constants={}}
end
local function calculated(r) return core.calculate(core.check(core.declare(r))) end
local function potential(ox,red,value)
  return {kind="standard potential",oxidized=ox,reduced=red,value=value}
end
local function edge(d,a,b)
  for _,item in ipairs(d.boundaries) do
    if (item.first==a and item.second==b) or (item.first==b and item.second==a) then return item end
  end
  error("missing pair")
end
local function segment(d,source)
  for _,item in ipairs(d.selection.segments) do if item.source==source then return item end end
end
local f=.059159349684781
local cu=raw("Cu","Cu(s),Cu^+,Cu^2+")
cu.constants={potential("Cu^2+","Cu^+",.159),potential("Cu^+","Cu(s)",.520)}
local reg=core.new_registry()
local prepared=reg.add(cu)
rejects(function() reg.select(prepared,{ph_min=0,ph_max=14}) end,"calculated equations")
local checked=reg.check(prepared)
local calc=reg.calculate(checked)
local handle,d=reg.select(calc,{ph_min=0,ph_max=14})
assert(handle==4 and not reg.get(calc).selection)
assert(reg.select(handle,{ph_min=0,ph_max=14})==handle)
assert(#d.selection.cells==140 and #d.selection.segments==1 and #d.selection.events==1)
local s=d.selection.segments[1]
near(s.ph_min,0);near(s.ph_max,14);near(s.equation.a,0)
near(s.equation.b,(.159+.520)/2-f)
assert(s.source==edge(d,"Cu(s)","Cu^2+").name)
local event=d.selection.events[1]
assert(event.species==2 and event.reaction["Cu^+"]==-2 and event.reaction["Cu(s)"]==1)
assert(event.reaction["Cu^2+"]==1 and not event.reaction["e^-"])
near(event.log_k,(.520-.159)/f)
assert(#d.selection.removed==2)
for _,cell in ipairs(d.selection.cells) do assert(#cell.species==2) end
s.equation.b=999
assert(reg.get(handle).selection.segments[1].equation.b~=999)
for _,options in ipairs({{}, {ph_min=1,ph_max=1}, {ph_min=0,ph_max=14,ph_step=0},
    {ph_min=0,ph_max=14,ph_step=-1}, {ph_min=0,ph_max=14,ph_step=1e-10},
    {ph_min=0,ph_max="nan"}, {ph_min="0x1",ph_max=14}, {ph_min=0,ph_max=14,typo=1}}) do
  local ok=pcall(reg.select,handle,options);assert(not ok)
end
local next_handle=reg.select(handle,{ph_min=-2,ph_max=15,ph_step=.2})
assert(next_handle==5)
-- A redox inversion at 1.037 must be found even with pH step=2.
local iron=raw("Fe","Fe(s),Fe^2+,FeO2^-");iron.concentration=1
iron.constants={potential("Fe^2+","Fe(s)",0),potential("FeO2^-","Fe^2+",4*f*1.037)}
local input=calculated(iron)
local coarse=core.select(input,{ph_min=0,ph_max=2,ph_step=2})
local fine=core.select(input,{ph_min=0,ph_max=2,ph_step=.01})
assert(#coarse.selection.events==1 and #coarse.selection.segments==3)
local replacement=edge(coarse,"Fe(s)","FeO2^-").name
near(segment(coarse,replacement).ph_min,1.037)
near(segment(coarse,replacement).ph_max,2)
near(coarse.selection.events[1].ph_min,1.037)
near(segment(fine,replacement).ph_min,segment(coarse,replacement).ph_min)
assert(#fine.selection.segments==#coarse.selection.segments)
-- Cascade: two successive eliminations, including a transient replacement.
local v=raw("V","V(s),V^+,V^2+,V^3+");v.concentration=1
v.constants={potential("V^+","V(s)",1),potential("V^2+","V^+",0),potential("V^3+","V^2+",-1)}
local cascade=core.select(calculated(v),{ph_min=0,ph_max=1})
assert(#cascade.selection.events==2 and #cascade.selection.segments==1)
near(cascade.selection.segments[1].equation.b,0)
assert(cascade.selection.events[1].species==2 and cascade.selection.events[2].species==3)
-- Equal redox lines remove a zero-width domain without claiming dismutation.
v.species="V(s),V^+,V^2+"
v.constants={potential("V^+","V(s)",0),potential("V^2+","V^+",0)}
local tied=core.select(calculated(v),{ph_min=0,ph_max=1})
assert(tied.selection.events[1].reason=="zero width")
-- Pure acid and precipitation cases include unbounded vertical segments.
local acid=raw("P","H3PO4(aq),H2PO4^-")
acid.constants={{kind="equilibrium constant",first="H3PO4(aq)",second="H2PO4^-",log_value=-2.2}}
local ac=core.select(calculated(acid),{ph_min=0,ph_max=14})
assert(#ac.selection.segments==1 and #ac.selection.events==0)
near(ac.selection.segments[1].equation.ph,2.2)
assert(ac.selection.segments[1].potential_min==-math.huge and ac.selection.segments[1].potential_max==math.huge)
-- A vertical boundary on a requested endpoint must not be lost.
local endpoint=core.select(calculated(acid),{ph_min=2.2,ph_max=3})
assert(#endpoint.selection.segments==1)
local out=core.select(calculated(acid),{ph_min=3,ph_max=4})
assert(#out.selection.segments==0 and out.selection.inventory[1].status=="outside range")
-- Five-species iron: 5 merged redox segments and 2 clipped vertical segments.
local fe=raw("Fe","Fe(s),Fe^2+,Fe^3+,Fe(OH)2(s),Fe(OH)3(s)")
fe.constants={potential("Fe^3+","Fe^2+",.77),potential("Fe^2+","Fe(s)",-.44),
 {kind="solubility product",solid="Fe(OH)2(s)",value=1e-15},
 {kind="solubility product",solid="Fe(OH)3(s)",value=1e-38}}
local selected=core.select(calculated(fe),{ph_min=0,ph_max=14})
assert(#selected.selection.segments==7 and #selected.selection.events==0)
local vertical=segment(selected,edge(selected,"Fe^2+","Fe(OH)2(s)").name)
near(vertical.ph_min,7.5);near(vertical.potential_min,-.44-f)
near(vertical.potential_max,.77-16.5*f)
-- Hydration never has a vertical line. A unique preferred solid is retained;
-- persistent equality requires explicit scientific information, not a name tie.
local hyd=raw("Fe","FeO(s),Fe(OH)2(s)")
hyd.constants={{kind="equilibrium constant",first="FeO(s)",second="Fe(OH)2(s)",log_value=1}}
local h=core.select(calculated(hyd),{ph_min=0,ph_max=1})
assert(#h.selection.segments==0 and h.selection.cells[1].species[1]==2)
hyd.constants[1].log_value=0
rejects(function() core.select(calculated(hyd),{ph_min=0,ph_max=1}) end,"non-unique same-oxidation")
hyd.constants[1].log_value=1e-10
rejects(function() core.select(calculated(hyd),{ph_min=0,ph_max=1}) end,"non-unique same-oxidation")
print("PASS pH selection and reconstruction")
