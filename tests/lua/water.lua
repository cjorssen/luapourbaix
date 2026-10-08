-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

package.path=assert(arg[1]):match('^(.*[/\\])')..'?.lua;'..package.path
local water=require('luapourbaix-water')
local w=water.compute{temperature=298.15}
local function near(a,b) assert(math.abs(a-b)<1e-12) end
near(w.a,-.059159349684781)
near(w.hydrogen_b,0);near(w.oxygen_b,1.229)
local shifted=water.compute{temperature=298.15,hydrogen_pressure=100,oxygen_pressure=.01}
near(shifted.hydrogen_b,w.a);near(shifted.oxygen_b,1.229+w.a/2)
local hot=water.compute{temperature=310,oxygen_standard_potential=1.2}
near(hot.a/w.a,310/298.15)
for _,o in ipairs({{temperature=310},{temperature=0},{temperature=298.15,hydrogen_pressure=0},
 {temperature=298.15,oxygen_pressure=-1},{temperature=298.15,oxygen_standard_potential=-1},
 {temperature=298.15,oxygen_pressure=math.huge},{}}) do assert(not pcall(water.compute,o)) end
local out=water.render(w,{xmin=0,xmax=14,ymin=-1,ymax=1.5})
for _,s in ipairs({'waterline{H2}','waterline{O2}','waterregion{H2}','waterregion{H2O}','waterregion{O2}'}) do assert(out:find(s,1,true)) end
local cropped=water.render(w,{xmin=0,xmax=1,ymin=2,ymax=3})
assert(not cropped:find('waterline',1,true));assert(not cropped:find('waterregion{H2O}',1,true))
assert(cropped:find('waterregion{O2}',1,true))
assert(not pcall(water.render,w,{xmin=0,xmax=0,ymin=-1,ymax=1}))
print('Water stability tests passed')
local rounded=water.compute{temperature=298.15,nernst_factor=.06,
 hydrogen_pressure=100,oxygen_pressure=.01}
near(rounded.a,-.06);near(rounded.hydrogen_b,-.06);near(rounded.oxygen_b,1.199)
near(water.compute{temperature=298.15,nernst_factor='auto'}.a,w.a)
for _,v in ipairs{0,-1,math.huge,'bad'} do
 assert(not pcall(water.compute,{temperature=298.15,nernst_factor=v}))
end
assert(not pcall(water.compute,{temperature=310,nernst_factor=.06}))
