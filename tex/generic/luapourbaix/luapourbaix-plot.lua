-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Pure viewport clipping and ordinary PGFPlots command generation.
local formula = ...
if type(formula) ~= "function" then formula=require("luapourbaix-tikz").formula end
local M = {}
local function fail(s) error("luapourbaix: "..s,0) end
local function finite(x)
  if type(x)~="number" or x~=x or math.abs(x)==math.huge then fail("non-finite plot coordinate or viewport") end
  return x
end
local function decimal(x) return string.format("%.17g",finite(x)==0 and 0 or x) end
local function number(value)
  if type(value)=="string" then
    local s=value:match("^%s*(.-)%s*$")
    if not s:match("^[+-]?[%d%.]+[eE]?[+-]?%d*$") then fail("plot bounds must be explicit decimal numbers") end
    value=tonumber(s)
  end
  return finite(value)
end
local function enabled(options,key,default)
  local value=options[key]
  if value==nil then return default end
  if value==true or value=="true" then return true end
  if value==false or value=="false" then return false end
  fail(key.." must be true or false")
end
local function value(q,x) return finite(q.a*x+q.b) end
local function clip(poly, distance)
  local result={}
  if #poly==0 then return result end
  local prev=poly[#poly]
  local dp=finite(distance(prev))
  for _,point in ipairs(poly) do
    local dc=finite(distance(point))
    if (dp<0) ~= (dc<0) then
      local t=dp/(dp-dc)
      result[#result+1]={finite(prev[1]+t*(point[1]-prev[1])),finite(prev[2]+t*(point[2]-prev[2]))}
    end
    if dc>=0 then result[#result+1]=point end
    prev,dp=point,dc
  end
  return result
end
local function polygon(diagram,region,box)
  local left,right=math.max(region.ph_min,box.xmin),math.min(region.ph_max,box.xmax)
  if left>=right then return {} end
  local p={{left,box.ymin},{right,box.ymin},{right,box.ymax},{left,box.ymax}}
  if region.lower then
    local q=diagram.boundaries_by_name[region.lower].equation
    p=clip(p,function(v) return v[2]-value(q,v[1]) end)
  end
  if region.upper then
    local q=diagram.boundaries_by_name[region.upper].equation
    p=clip(p,function(v) return value(q,v[1])-v[2] end)
  end
  return p
end
local function size_and_center(p,box)
  if #p<3 then return 0 end
  local area,x,y=0,0,0
  local w,h=box.xmax-box.xmin,box.ymax-box.ymin
  local previous=p[#p]
  for _,v in ipairs(p) do
    local ax,ay=(previous[1]-box.xmin)/w,(previous[2]-box.ymin)/h
    local bx,by=(v[1]-box.xmin)/w,(v[2]-box.ymin)/h
    local cross=ax*by-bx*ay
    area,x,y=area+cross,x+(ax+bx)*cross,y+(ay+by)*cross
    previous=v
  end
  if area==0 then return 0 end
  return math.abs(area)/2,{box.xmin+w*x/(3*area),box.ymin+h*y/(3*area)}
end
local function inside(p,point,box)
  local sign
  local width,height=box.xmax-box.xmin,box.ymax-box.ymin
  for i,v in ipairs(p) do
    local w=p[i%#p+1]
    local cross=((w[1]-v[1])/width)*((point[2]-v[2])/height)-
      ((w[2]-v[2])/height)*((point[1]-v[1])/width)
    if math.abs(cross)>64*2^-52 then
      if sign~=nil and (cross>0)~=sign then return false end
      sign=cross>0
    end
  end
  return true
end
local function line(q,item,box)
  if q.kind=="vertical" then
    local x=q.ph
    if x<item.ph_min or x>item.ph_max then return end
    local lo=math.max(item.potential_min or -math.huge,box.ymin)
    local hi=math.min(item.potential_max or math.huge,box.ymax)
    if x<box.xmin or x>box.xmax or lo>=hi then return end
    return {{x,lo},{x,hi}}
  end
  if q.kind~="potential" then return end
  local lo,hi=math.max(item.ph_min,box.xmin),math.min(item.ph_max,box.xmax)
  if q.a==0 then
    if q.b<box.ymin or q.b>box.ymax then return end
  else
    local a,b=(box.ymin-q.b)/q.a,(box.ymax-q.b)/q.a
    lo,hi=math.max(lo,math.min(a,b)),math.min(hi,math.max(a,b))
  end
  if lo>=hi then return end
  return {{lo,value(q,lo)},{hi,value(q,hi)}}
end

function M.geometry(diagram,options)
  if not diagram.selection then fail("plot requires a selected diagram; run pourbaix/finalize first") end
  local box={xmin=number(options.xmin),xmax=number(options.xmax),
    ymin=number(options.ymin),ymax=number(options.ymax)}
  if box.xmin>=box.xmax or box.ymin>=box.ymax then fail("plot bounds must be strictly increasing") end
  finite(box.xmax-box.xmin);finite(box.ymax-box.ymin)
  local result={box=box,domains={},removed_domains={},boundaries={},removed={},provisional={},labels={},removed_labels={}}
  local function domain(region,collection,label_collection)
    local p=polygon(diagram,region,box)
    local area,center=size_and_center(p,box)
    if area>0 then
      if region.kind == "incompatible" then
        local lo=math.max(box.ymin,value(diagram.boundaries_by_name[region.lower].equation,center[1]))
        local hi=math.min(box.ymax,value(diagram.boundaries_by_name[region.upper].equation,center[1]))
        center[2]=lo+.75*(hi-lo)
      end
      collection[#collection+1]={species=region.species,kind=region.kind,points=p}
      local old=label_collection[region.species]
      if not old or area>old.area then
        label_collection[region.species]={species=region.species,point=center,area=area}
      end
    end
  end
  for _,region in ipairs(diagram.selection.domains) do domain(region,result.domains,result.labels) end
  local placement=options.label_placement or "centroid"
  if placement~="centroid" and placement~="largest piece" then fail("unknown domain label placement") end
  if placement=="centroid" then
    for i,label in pairs(result.labels) do
      local total,x,y=0,0,0
      for _,r in ipairs(result.domains) do
        if r.species==i then
          local a,c=size_and_center(r.points,box)
          total,x,y=total+a,x+a*c[1],y+a*c[2]
        end
      end
      local center={x/total,y/total}
      for _,r in ipairs(result.domains) do
        if r.species==i and inside(r.points,center,box) then label.point=center;break end
      end
    end
  end
  for _,event in ipairs(diagram.selection.events) do
    if event.reason=="disproportionation" then
      -- Inverted limits do NOT define a stable domain. This is the diagnostic
      -- band between them, explicitly labeled as incompatible by the renderer.
      domain({species=event.species,kind="incompatible",ph_min=event.ph_min,ph_max=event.ph_max,
        lower=event.upper,upper=event.lower},result.removed_domains,result.removed_labels)
    end
  end
  for _,segment in ipairs(diagram.selection.segments) do
    local points=line(segment.equation,segment,box)
    if points then result.boundaries[#result.boundaries+1]={name=segment.name,source=segment.source,points=points} end
  end
  for _,item in ipairs(diagram.selection.removed) do
    local points=line(diagram.boundaries_by_name[item.source].equation,item,box)
    if points then result.removed[#result.removed+1]={name=item.source,points=points} end
  end
  for _,b in ipairs(diagram.boundaries) do
    local points=line(b.equation,{ph_min=diagram.selection.ph_min,ph_max=diagram.selection.ph_max},box)
    if points then result.provisional[#result.provisional+1]={name=b.name,points=points} end
  end
  return result
end
local function coordinates(points)
  local result={}
  for _,p in ipairs(points) do result[#result+1]="("..decimal(p[1])..","..decimal(p[2])..")" end
  return table.concat(result," ")
end

-- Deterministic saturation-degree coloring of the selected species graph.
-- No viewport information participates: colors remain stable under zooming.
function M.colors(diagram,count)
  local graph,colors={},{}
  for _,r in ipairs(diagram.selection.domains) do graph[r.species]=graph[r.species] or {} end
  for _,b in ipairs(diagram.selection.final_boundaries) do
    graph[b.first]=graph[b.first] or {}; graph[b.second]=graph[b.second] or {}
    graph[b.first][b.second]=true;graph[b.second][b.first]=true
  end
  while true do
    local best,saturation,degree=nil,-1,-1
    for i=1,#diagram.species do
      if graph[i] and not colors[i] then
        local used,n,deg={},0,0
        for j in pairs(graph[i]) do
          deg=deg+1
          if colors[j] and not used[colors[j]] then used[colors[j]]=true;n=n+1 end
        end
        if n>saturation or (n==saturation and deg>degree) then best,saturation,degree=i,n,deg end
      end
    end
    if not best then break end
    local used={}
    for j in pairs(graph[best]) do if colors[j] then used[colors[j]]=true end end
    local c=1;while used[c] do c=c+1 end
    if c>count then fail("domain palette exhausted; provide more distinct domain colors or patterns") end
    colors[best]=c
  end
  return colors
end
local function letters(n)
  local s=""
  repeat n=n-1;s=string.char(65+n%26)..s;n=math.floor(n/26) until n==0
  return s
end
local function species_index(d,id)
  local s=d.species_by_id[id]
  if not s then fail("unknown domain species: "..tostring(id)) end
  return s.index
end
function M.appearance(d,options)
  local mode=options.coloring or "adjacent"
  if mode~="adjacent" and mode~="patterns" and mode~="phase" and mode~="none" then fail("unknown domain coloring") end
  local colors={}
  if (mode=="adjacent" or mode=="patterns") and enabled(options,"domain_fills",true) then
    local palette=options.palette or (mode=="patterns"
      and "north east lines,north west lines,dots,horizontal lines,vertical lines,crosshatch"
      or "blue!15,orange!20,green!15,violet!15,yellow!25,red!15")
    local n,seen=0,{}
    for c in (palette..","):gmatch("(.-),") do
      c=c:match("^%s*(.-)%s*$")
      if c=="" or seen[c] then fail("domain colors or patterns must be nonempty and distinct") end
      seen[c]=true;n=n+1
    end
    colors=M.colors(d,n)
  end
  local records,labels={},{}
  for index,r in ipairs(options.domains or {}) do
    local i=species_index(d,r.species)
    if records[i] then fail("duplicate domain customization for "..r.species) end
    records[i]={index=index}
    if r.at and r.at~="" then
      local x,y=r.at:match("^%s*([^,]+),([^,]+)%s*$")
      if not x then fail("domain label at requires pH,potential (two decimal numbers)") end
      records[i].point={number(x),number(y)}
    end
  end
  local labelmode=options.label_mode or "species"
  if labelmode~="species" and labelmode~="letters" then fail("unknown domain label mode") end
  if labelmode=="letters" then
    local indices={}
    if options.letter_species and options.letter_species~="" then
      local seen={}
      for id in (options.letter_species..","):gmatch("(.-),") do
        id=id:match("^%s*(.-)%s*$")
        local i=species_index(d,id)
        if seen[i] then fail("duplicate letter species: "..id) end
        seen[i]=true;indices[#indices+1]=i
      end
    else
      local active={}
      for _,r in ipairs(d.selection.domains) do active[r.species]=true end
      for i=1,#d.species do if active[i] then indices[#indices+1]=i end end
    end
    for n,i in ipairs(indices) do labels[i]="$"..letters(n).."$" end
  end
  local boundary_records={}
  for i,id in ipairs(options.boundary_ids or {}) do
    if not d.selection.final_by_name[id] then fail("unknown final boundary identifier: "..id) end
    if boundary_records[id] then fail("duplicate boundary customization: "..id) end
    boundary_records[id]=i
  end
  return {colors=colors,records=records,labels=labels,coloring=mode,boundary_records=boundary_records}
end

function M.render(diagram,options)
  local g=M.geometry(diagram,options)
  local appearance=M.appearance(diagram,options)
  local out={}
  local function emit(x) out[#out+1]=x end
  local labels=enabled(options,"boundary_labels",true)
  local function boundaries(items,kind,showlabels)
    for _,b in ipairs(items) do
      emit("\\luapourbaixplotboundaryappearance{"..(kind=="final" and appearance.boundary_records[b.name] or 0).."}")
      emit("\\luapourbaixplotline{"..kind.."}{"..coordinates(b.points).."}{"..b.name.."}{"..(showlabels and "1" or "0").."}")
    end
  end
  local function domains(items,kind)
    for _,r in ipairs(items) do
      local record=appearance.records[r.species]
      emit("\\luapourbaixplotappearance{"..(kind and 0 or (appearance.colors[r.species] or 0)).."}{"..(record and record.index or 0).."}")
      emit("\\luapourbaixplotfill{"..(kind or r.kind).."}{"..r.species.."}{"..coordinates(r.points).."}")
    end
  end
  local function names(items,kind)
    for i,species in ipairs(diagram.species) do
      if items[i] then
        local record=appearance.records[i]
        local label=appearance.labels[i] or formula(species,true)
        local point=record and record.point or items[i].point
        emit("\\luapourbaixplotappearance{0}{"..(record and record.index or 0).."}")
        if kind=="removed" then label=label.." \\hbox{(incompatible domain)}" end
        emit("\\luapourbaixplotname{"..kind.."}{"..i.."}{"..coordinates({point}).."}{"..label.."}")
      end
    end
  end
  if enabled(options,"domain_fills",true) and appearance.coloring~="none" then domains(g.domains) end
  if enabled(options,"removed_domains",false) then domains(g.removed_domains,"removed") end
  if enabled(options,"provisional_boundaries",false) then boundaries(g.provisional,"provisional",enabled(options,"provisional_labels",false)) end
  if enabled(options,"removed_boundaries",false) then boundaries(g.removed,"removed",enabled(options,"provisional_labels",false)) end
  if enabled(options,"boundaries",true) then boundaries(g.boundaries,"final",labels) end
  if enabled(options,"domain_labels",true) then names(g.labels,"final") end
  if enabled(options,"removed_domains",false) then names(g.removed_labels,"removed") end
  return table.concat(out,""),g
end
return M
