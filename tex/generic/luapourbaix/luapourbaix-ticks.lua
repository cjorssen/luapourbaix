-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Pure selection of numerical extra ticks; no TeX or PGFPlots state mutation.
local M={}
local function fail(s) error('luapourbaix: extra ticks: '..s,0) end
local function close(a,b)
  return math.abs(a-b)<=64*2^-52*math.max(1,math.abs(a),math.abs(b))
end
local function inside(x,lo,hi) return (x>=lo or close(x,lo)) and (x<=hi or close(x,hi)) end
local function select_ticks(candidates,request,kind)
  request=tostring(request or 'none'):match('^%s*(.-)%s*$')
  if request=='false' then request='none' elseif request=='true' then request='all' end
  local wanted={}
  if request~='all' and request~='none' and request~='' then
    for name in (request..','):gmatch('(.-),') do
      name=name:match('^%s*(.-)%s*$')
      local c=candidates[name]
      if not c then fail('unknown final boundary '..name) end
      if c.kind~=kind then fail('boundary '..name..' cannot supply an extra '..kind..' tick') end
      wanted[name]=true
    end
  end
  local values={}
  for name,c in pairs(candidates) do
    if c.kind==kind and c.eligible and (request=='all' or wanted[name]) then values[#values+1]=c.value end
  end
  table.sort(values)
  local unique={}
  for _,v in ipairs(values) do if not unique[#unique] or not close(v,unique[#unique]) then unique[#unique+1]=v end end
  return unique
end
function M.element(d,g,o)
  local visible={}
  for _,b in ipairs(g.boundaries) do visible[b.name]=true end
  local candidates={}
  for _,b in ipairs(d.selection.final_boundaries) do
    local q=b.equation
    local c={kind=q.kind=='vertical' and 'x' or 'y',value=q.ph or q.b,eligible=visible[b.name]}
    if c.kind=='y' then
      local reaches_zero=false
      for _,i in ipairs(b.segments) do
        local s=d.selection.segments[i]
        if inside(0,s.ph_min,s.ph_max) then reaches_zero=true end
      end
      c.eligible=c.eligible and reaches_zero and inside(0,g.box.xmin,g.box.xmax)
        and inside(q.b,g.box.ymin,g.box.ymax)
    end
    candidates[b.name]=c
  end
  return select_ticks(candidates,o.x,'x'),select_ticks(candidates,o.y,'y')
end
function M.water(d,box,request)
  local candidates={}
  for id,b in pairs({H2=tonumber(d.hydrogen_b),O2=tonumber(d.oxygen_b)}) do
    candidates[id]={kind='y',value=b,eligible=inside(0,tonumber(box.xmin),tonumber(box.xmax))
      and inside(b,tonumber(box.ymin),tonumber(box.ymax))}
  end
  return select_ticks(candidates,request,'y')
end
-- Existing literal numeric ticks are recognized without evaluating TeX or PGF
-- expressions. The caller retains the entire original list, including tokens.
function M.additional(values,existing)
  local old={}
  for item in ((existing or '')..','):gmatch('(.-),') do
    local n=tonumber(item)
    if n and n==n and math.abs(n)<math.huge then old[#old+1]=n end
  end
  local out={}
  for _,v in ipairs(values) do
    local found=false
    for _,w in ipairs(old) do if close(v,w) then found=true;break end end
    if not found then out[#out+1]=string.format('%.17g',v==0 and 0 or v) end
  end
  return table.concat(out,',')
end
return M
