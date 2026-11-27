-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Independent ideal-gas water stability model; potentials are relative to SHE.
-- Default provenance: Malkow, Pilenga and Blagoeva (2021), JRC120120,
-- DOI 10.2760/732809, entry 720 (printed p.105), SATP entry 1069 (p.146).
-- https://publications.jrc.ec.europa.eu/repository/bitstream/JRC120120/jrc120120_online.pdf
-- 1.229 V is a rounded standard reduction potential at 298.15 K, p0=1 bar.
-- Ideal gas convention: https://goldbook.iupac.org/terms/view/I02935
-- Pure liquid water has unit activity; no dissolved gas/Henry-law model.
local M = {}
local function fail(s) error('luapourbaix: water overlay: '..s, 0) end
local function number(x, name)
  if type(x)=='string' then
    x=x:match('^%s*(.-)%s*$')
    if not x:match('^[+-]?[%d%.]+[eE]?[+-]?%d*$') then fail(name..' must be a decimal number') end
  end
  x=tonumber(x)
  if not x or x~=x or math.abs(x)==math.huge then fail(name..' must be finite') end
  return x
end
local function positive(x,name)
  x=number(x,name)
  if x<=0 then fail(name..' must be positive') end
  return x
end
local function optional(x,default) if x==nil or x=='' then return default end return x end
local function log10(x) return math.log(x)/math.log(10) end
function M.compute(o)
  local t=positive(o.temperature,'temperature in kelvins')
  local h=positive(optional(o.hydrogen_pressure,1),'hydrogen partial pressure in bar')
  local ox=positive(optional(o.oxygen_pressure,1),'oxygen partial pressure in bar')
  local e=optional(o.oxygen_standard_potential,t==298.15 and 1.229 or nil)
  if not e then fail('oxygen standard potential is required away from 298.15 K; no temperature extrapolation is available') end
  e=number(e,'oxygen standard potential in V versus SHE')
  local f=optional(o.nernst_factor,'auto')
  if f=='auto' then f=1.380649e-23/1.602176634e-19*t*math.log(10) end
  f=positive(f,'Nernst factor in V')
  local result={temperature=t,nernst_factor=f,hydrogen_pressure=h,oxygen_pressure=ox,
    oxygen_standard_potential=e,a=-f,hydrogen_b=-f/2*log10(h),oxygen_b=e+f/4*log10(ox)}
  for k,v in pairs(result) do number(v,k) end
  if result.oxygen_b<=result.hydrogen_b then
    fail('these parameters leave no open water stability region between the two equilibria')
  end
  return result
end
-- Sutherland-Hodgman clipping against the two affine equilibrium supports.
local function clip(poly,a,b,side)
  local out={}
  local prev=poly[#poly]
  if not prev then return out end
  local function distance(p) return number(side*(p[2]-a*p[1]-b),'clipping distance') end
  local dp=distance(prev)
  for _,p in ipairs(poly) do
    local d=distance(p)
    if (d<0)~=(dp<0) then
      local t=dp/(dp-d)
      out[#out+1]={prev[1]+t*(p[1]-prev[1]),prev[2]+t*(p[2]-prev[2])}
    end
    if d>=0 then out[#out+1]=p end
    prev,dp=p,d
  end
  return out
end
local function decimal(v) return string.format('%.17g',number(v,'coordinate')) end
local function coordinates(points)
  local out={}
  for _,p in ipairs(points) do out[#out+1]='('..decimal(p[1])..','..decimal(p[2])..')' end
  return table.concat(out,' ')
end
function M.render(d,o)
  local xmin,xmax=number(o.xmin,'xmin'),number(o.xmax,'xmax')
  local ymin,ymax=number(o.ymin,'ymin'),number(o.ymax,'ymax')
  if xmin>=xmax or ymin>=ymax then fail('axis bounds must be strictly increasing') end
  local a,h,b=number(d.a,'prepared slope'),number(d.hydrogen_b,'prepared hydrogen intercept'),number(d.oxygen_b,'prepared oxygen intercept')
  if a>=0 or h>=b then fail('prepare the water model before plotting') end
  local out={}
  local function emit(s) out[#out+1]=s end
  for _,id in ipairs({'H2','H2O','O2'}) do
    local poly={{xmin,ymin},{xmax,ymin},{xmax,ymax},{xmin,ymax}}
    if id=='H2' then poly=clip(poly,a,h,-1)
    elseif id=='O2' then poly=clip(poly,a,b,1)
    else poly=clip(clip(poly,a,h,1),a,b,-1) end
    local area=0
    for i=2,#poly-1 do
      area=area+(poly[i][1]-poly[1][1])*(poly[i+1][2]-poly[1][2])
        -(poly[i+1][1]-poly[1][1])*(poly[i][2]-poly[1][2])
    end
    number(area,'clipped polygon area')
    if #poly>=3 and area>0 then
      -- The vertex mean lies in this convex clipped region.
      local x,y=0,0
      for _,p in ipairs(poly) do x=x+p[1]/#poly;y=y+p[2]/#poly end
      emit('\\luapourbaixwaterregion{'..id..'}{'..coordinates(poly)..'}{'..coordinates({{x,y}})..'}')
    end
  end
  for _,pair in ipairs({{'H2',h},{'O2',b}}) do
    local left=math.max(xmin,(ymax-pair[2])/a)
    local right=math.min(xmax,(ymin-pair[2])/a)
    if left<right then emit('\\luapourbaixwaterline{'..pair[1]..'}{'..coordinates({{left,a*left+pair[2]},{right,a*right+pair[2]}})..'}') end
  end
  return table.concat(out)
end
return M
