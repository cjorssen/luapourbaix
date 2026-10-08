-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

package.path=assert(arg[1]):match('^(.*[/\\])')..'?.lua;'..package.path
local core=dofile(arg[1])
local plot=require('luapourbaix-plot')
local ticks=require('luapourbaix-ticks')
local d=core.select(core.calculate(core.check(core.declare{
 element='Ni',species='Ni(s),Ni^2+,Ni(OH)2(s)',temperature=298.15,concentration=.01,
 boundary_convention='equal concentrations',constants={}})),{ph_min=0,ph_max=14})
local g=plot.geometry(d,{xmin=0,xmax=14,ymin=-2,ymax=2})
local x,y=ticks.element(d,g,{x='all',y='all'})
assert(#x==1 and math.abs(x[1]-7.397)<1e-12)
assert(#y==1 and math.abs(y[1]-(-.257-.059159349684781))<1e-12)
local _,excluded=ticks.element(d,g,{y='2'})
assert(#excluded==0) -- hydroxide/metal exists only above pH 7.397.
local xx,yy=ticks.element(d,g,{x='none',y='none'});assert(#xx+#yy==0)
assert(not pcall(ticks.element,d,g,{x='1'}))
assert(not pcall(ticks.element,d,g,{y='typo'}))
local cropped=plot.geometry(d,{xmin=2,xmax=14,ymin=-2,ymax=2})
local _,none=ticks.element(d,cropped,{y='all'});assert(#none==0)
local cropped2=plot.geometry(d,{xmin=0,xmax=5,ymin=-2,ymax=2})
local none2=ticks.element(d,cropped2,{x='all'});assert(#none2==0)
assert(ticks.additional({0,1.5,2},'0, 2, 9')=='1.5')
assert(ticks.additional({1},'\\somevalue')=='1') -- no evaluation of user text.
local water={hydrogen_b=0,oxygen_b=1.229}
local box={xmin=0,xmax=14,ymin=-2,ymax=2}
assert(#ticks.water(water,box,'all')==2)
assert(ticks.water(water,box,'O2')[1]==1.229)
assert(not pcall(ticks.water,water,box,'bad'))
print('PASS: selected boundary ticks, clipping, origin support and numeric merging')
