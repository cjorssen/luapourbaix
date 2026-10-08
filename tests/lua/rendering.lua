-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Viewport geometry, final naming, diagnostic bands and generic render output.
package.path=assert(arg[1]):match("^(.*[/\\])").."?.lua;"..package.path
local core=dofile(arg[1])
local plot=require("luapourbaix-plot")
local tikz=require("luapourbaix-tikz")
local function near(a,b) assert(math.abs(a-b)<1e-10,tostring(a).." != "..tostring(b)) end
local function rejects(f,s)
 local ok,e=pcall(f); assert(not ok and tostring(e):find(s,1,true),tostring(e))
end
local function selected(element,species)
 return core.select(core.calculate(core.check(core.declare({element=element,species=species,
  temperature=298.15,concentration=.01,boundary_convention="equal concentrations",constants={}}))),
  {ph_min=0,ph_max=14})
end
local d=selected("Fe","Fe(s),Fe^2+,Fe^3+,Fe(OH)2(s),Fe(OH)3(s)")
assert(#d.selection.final_boundaries==7)
assert(d.selection.final_by_name["a"].source=="a-temp")
assert(d.selection.final_by_name["5"].source=="8-temp")
for _,b in ipairs(d.selection.final_boundaries) do
 assert((b.kind=="redox" and b.name:match("^%d+$")) or b.name:match("^[a-z]+$"))
 for _,i in ipairs(b.segments) do assert(d.selection.segments[i].name==b.name) end
end
local box={xmin=0,xmax=14,ymin=-1,ymax=1}
local g=plot.geometry(d,box)
assert(#g.boundaries==7 and #g.domains==8)
local area=0
for _,r in ipairs(g.domains) do
 local signed=0
 for i,p in ipairs(r.points) do
  assert(p[1]>=0 and p[1]<=14 and p[2]>=-1-1e-12 and p[2]<=1+1e-12)
  local prev=r.points[i==1 and #r.points or i-1]
  signed=signed+prev[1]*p[2]-p[1]*prev[2]
 end
 area=area+math.abs(signed)/2
end
near(area,28) -- The five existence/predominance regions cover the viewport.
for _,b in ipairs(g.boundaries) do
 local final=d.selection.final_by_name[b.name]
 for _,p in ipairs(b.points) do
  if final.kind=="redox" then near(p[2],final.equation.a*p[1]+final.equation.b)
  else near(p[1],final.equation.ph) end
 end
end
local zoom=plot.geometry(d,{xmin=8,xmax=10,ymin=-.8,ymax=-.6})
assert(#zoom.domains>=1)
for _,r in ipairs(zoom.domains) do for _,p in ipairs(r.points) do
 assert(p[1]>=8-1e-12 and p[1]<=10+1e-12 and p[2]>=-.8-1e-12 and p[2]<=-.6+1e-12)
end end
local cu=selected("Cu","Cu(s),Cu^+,Cu^2+")
local cg=plot.geometry(cu,{xmin=0,xmax=14,ymin=0,ymax=.6})
assert(#cg.boundaries==1 and #cg.removed_domains==1 and #cg.removed==2)
assert(cg.labels[1] and cg.labels[3] and not cg.labels[2])
assert(cg.removed_labels[2])
local min,max=1,0
for _,p in ipairs(cg.removed_domains[1].points) do min=math.min(min,p[2]);max=math.max(max,p[2]) end
near(min,.159);near(max,.520-2*.059159349684781)
assert(cg.removed_labels[2].point[2]>cu.selection.segments[1].equation.b)
local output=plot.render(cu,{xmin=0,xmax=14,ymin=0,ymax=.6,removed_domains=true})
assert(output:find("incompatible domain",1,true))
assert(output:find("\\luapourbaixplotline{final}",1,true))
assert(not output:find("directlua",1,true) and not output:find("pgfplots@",1,true))
local none=plot.render(cu,{xmin=0,xmax=14,ymin=0,ymax=.6,domain_fills=false,domain_labels=false,boundaries=false})
assert(none=="")
local map=tikz.render(cu,"map")
assert(map:find("(-species-1) at (0,0)",1,true))
assert(map:find("(-species-3) at (0,2)",1,true))
assert(map:find("map removed species",1,true) and map:find("map long edge",1,true))
assert(tikz.render(d,"map"):find("(-species-4) at (1,1)",1,true))
local increasing={acidity_direction="increasing"}
assert(tikz.render(d,"map",increasing):find("(-species-4) at (0,1)",1,true))
assert(tikz.render(d,"acidity",increasing):find("(-species-4) at (0,-1.6)",1,true))
assert(tikz.render(d,"oxidation",increasing)==tikz.render(d,"oxidation"))
assert(tikz.render(d,"map"):find("(-species-4) at (1,1)",1,true))
rejects(function() tikz.render(d,"acidity",{acidity_direction="wrong"}) end,"acidity direction")

-- Display notation preserves numeric data and supports all classification pics.
local roman={oxidation_number_format="roman"}
for _,kind in ipairs({"oxidation","acidity","map"}) do
 local original=tikz.render(d,kind)
 local formatted=tikz.render(d,kind,roman)
 assert(formatted:find("$+\\hbox{III}$",1,true))
 assert(formatted:find("{$0$}",1,true))
 assert(tikz.render(d,kind)==original)
 rejects(function() tikz.render(d,kind,{oxidation_number_format="wrong"}) end,
   "oxidation number format")
end
-- Isolated label fixtures exercise signs, subtractive notation and fallbacks.
for _,case in ipairs({{-1,"-\\hbox{I}"},{4,"+\\hbox{IV}"},{9,"+\\hbox{IX}"},
 {49,"+\\hbox{XLIX}"},{3999,"+\\hbox{MMMCMXCIX}"},{4000,"+4000"},
 {8/3,"+2.66667"},{3.999999,"+4"}}) do
 local fixture={oxidation_groups={{oxidation_number=case[1],species={}}}}
 assert(tikz.render(fixture,"oxidation",roman):find("{$"..case[2].."$}",1,true))
end

rejects(function() plot.geometry({},box) end,"selected diagram")
rejects(function() plot.geometry(d,{xmin=0,xmax=14,ymin=1,ymax=-1}) end,"strictly increasing")
rejects(function() plot.geometry(d,{xmin="0x1",xmax=14,ymin=-1,ymax=1}) end,"decimal")
rejects(function() plot.render(d,{xmin=0,xmax=14,ymin=-1,ymax=1,domain_fills="maybe"}) end,"true or false")
-- More than 26 vertical identifiers: synthetic successive hydrolysis constants.
local species,constants={"Fe^2+"},{}
for i=1,27 do
 local formula="Fe(OH)"..(i==1 and "" or i)
 local charge=2-i
 local id=formula..(charge==0 and "(aq)" or ("^"..(math.abs(charge)==1 and "" or math.abs(charge))..(charge>0 and "+" or "-")))
 species[#species+1]=id
 constants[#constants+1]={kind="equilibrium constant",first=species[#species-1],second=id,log_value=-i}
end
local synthetic=core.select(core.calculate(core.check(core.declare({element="Fe",species=species,
 temperature=298.15,concentration=.01,boundary_convention="equal concentrations",
 thermodynamic_database="none",constants=constants}))),{ph_min=0,ph_max=28,ph_step=1})
assert(#synthetic.selection.final_boundaries==27 and synthetic.selection.final_by_name.aa)
near(synthetic.selection.final_by_name.aa.equation.ph,27)
print("PASS final naming, polygons, overlays and classification map")
-- Adjacent pairs receive distinct colors, independent of plot clipping.
local colors=plot.colors(d,6)
for _,edge in ipairs(d.selection.final_boundaries) do assert(colors[edge.first]~=colors[edge.second]) end
rejects(function() plot.colors(d,1) end,'palette exhausted')
local appearance=plot.appearance(d,{label_mode='letters'})
for i=1,5 do assert(appearance.labels[i]=='$'..string.char(64+i)..'$') end
local subset=plot.appearance(d,{label_mode='letters',letter_species='Fe^3+,Fe(s)'})
assert(subset.labels[3]=='$A$' and subset.labels[1]=='$B$' and not subset.labels[2])
local config=plot.appearance(d,{domains={{species='Fe^2+',at='7,0.1'}}})
near(config.records[2].point[1],7);near(config.records[2].point[2],.1)
rejects(function() plot.appearance(d,{palette='red,red'}) end,'distinct')
rejects(function() plot.appearance(d,{domains={{species='Zn^2+'}}}) end,'unknown domain species')
rejects(function() plot.appearance(d,{domains={{species='Fe(s)',at='0/0,1'}}}) end,'decimal')
rejects(function() plot.appearance(d,{label_mode='letters',letter_species='Fe(s),Fe(s)'}) end,'duplicate')
-- Analytic centroid of a horizontal copper region.
near(cg.labels[3].point[1],7)
near(cg.labels[3].point[2],(cu.selection.segments[1].equation.b+.6)/2)
-- Two disconnected rectangles: the whole centroid is in the gap, so use
-- the larger component. A subdivision must not bias the area centroid.
local disconnected={species={{}},boundaries={},boundaries_by_name={},selection={
 domains={{species=1,kind='existence',ph_min=0,ph_max=2},
 {species=1,kind='existence',ph_min=8,ph_max=9}},events={},segments={},removed={},
 ph_min=0,ph_max=10}}
local dg=plot.geometry(disconnected,{xmin=0,xmax=10,ymin=0,ymax=2})
near(dg.labels[1].point[1],1);near(dg.labels[1].point[2],1)
disconnected.selection.domains[2].ph_min=2;disconnected.selection.domains[2].ph_max=6
local joined=plot.geometry(disconnected,{xmin=0,xmax=10,ymin=0,ymax=2})
near(joined.labels[1].point[1],3);near(joined.labels[1].point[2],1)
assert(plot.appearance(synthetic,{label_mode='letters'}).labels[27]=='$AA$')
print('PASS adjacency palette, domain labels and area centroids')
-- A gap below the first component must not pass a one-sided cross-product test.
disconnected.boundaries_by_name={lo={equation={a=0,b=3}},hi={equation={a=0,b=1}}}
disconnected.selection.domains={
 {species=1,kind='existence',ph_min=0,ph_max=1,lower='lo'},
 {species=1,kind='existence',ph_min=3,ph_max=4,upper='hi'}}
local diagonal=plot.geometry(disconnected,{xmin=0,xmax=4,ymin=0,ymax=4})
near(diagonal.labels[1].point[1],.5);near(diagonal.labels[1].point[2],3.5)
local boundary_appearance=plot.appearance(d,{boundary_ids={'1','a'}})
assert(boundary_appearance.boundary_records['1']==1 and boundary_appearance.boundary_records.a==2)
rejects(function() plot.appearance(d,{boundary_ids={'missing'}}) end,'unknown final boundary')
rejects(function() plot.appearance(d,{boundary_ids={'1','1'}}) end,'duplicate boundary')
-- Pattern assignments obey exactly the retained chemical adjacency graph.
local patterned=plot.appearance(d,{coloring='patterns',palette='north east lines,north west lines,dots,crosshatch'})
for _,edge in ipairs(d.selection.final_boundaries) do
 assert(patterned.colors[edge.first]~=patterned.colors[edge.second])
end
rejects(function() plot.appearance(d,{coloring='patterns',palette='dots'}) end,'exhausted')
rejects(function() plot.appearance(d,{coloring='patterns',palette='dots, dots'}) end,'distinct')
assert(next(plot.appearance(d,{coloring='patterns',palette='',domain_fills=false}).colors)==nil)
-- The recovery diagnostic must name the available public finalization key.
rejects(function() plot.geometry({}, {}) end, 'run pourbaix/finalize first')
