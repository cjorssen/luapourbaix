-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Report presentation must preserve the scientific snapshot and inert text.
package.path=assert(arg[1]):match('^(.*[/\\])')..'?.lua;'..package.path
local core=dofile(arg[1])
local presenter=assert(loadfile(assert(arg[1]):match('^(.*[/\\])')..'luapourbaix-report.lua'))(
  require('luapourbaix-tikz').formula)
local prepared=core.declare({element='Cu',temperature=298.15,concentration=.01,
  species='Cu(s),Cu^+,Cu^2+',boundary_convention='equal concentrations',constants={}})
local ok,err=pcall(presenter.render,prepared)
assert(not ok and tostring(err):find('requires a selected diagram',1,true))
local selected=core.select(core.calculate(core.check(prepared)),{ph_min=0,ph_max=14})
local out=presenter.render(selected)
assert(out:find('disproportionation',1,true))
assert(out:find('replacement: 2-temp',1,true))
-- Independent two-electron average E0=(.159+.520)/2, with aqueous Cu(II)=.01.
local expected=(.159+.520)/2+8.31446261815324*298.15*math.log(10)/96485.33212331002/2*math.log(.01)/math.log(10)
assert(math.abs(selected.boundaries_by_name['2-temp'].equation.b-expected)<1e-12)
assert(out:find(string.format('%.17g',selected.boundaries_by_name['2-temp'].equation.b),1,true))
assert(out:find('Derivation of $\\log_{10}K$',1,true))
assert(presenter.render(selected)==out)
assert(selected.selection.final_boundaries[1].name=='1')
-- Free source text is not executable TeX, even if later catalogue metadata changes.
selected.thermodynamics.inputs[1].label='bad\\input{secret}%#&_~^$'
local escaped=presenter.render(selected)
assert(not escaped:find('\\input{secret}',1,true))
assert(escaped:find('bad\\char92{}input\\char123{}secret\\char125{}',1,true))
assert(escaped:find('\\char37{}\\char35{}\\char38{}\\char95{}',1,true))
print('report tests passed')

-- Report inputs retain explicit dissolution normalization and the original K.
local u=core.select(core.calculate(core.check(core.declare{
 element='U',temperature=298.15,concentration=1,
 species='UO2^2+,UO2(OH)2(s)',boundary_convention='equal concentrations',
 thermodynamic_database='none',constants={
 {kind='solubility product',solid='UO2(OH)2(s)',log_value=-24,
 reaction='UO2(OH)2(s) = UO2^2+ + 2 OH^-'},
 {kind='water ion product',log_value=-14}}})),{ph_min=0,ph_max=14})
local report=presenter.render(u)
assert(report:find('reportnumber{-24}',1,true))
assert(report:find(' $=$ ',1,true))
assert(u.thermodynamics.inputs[1].coefficients['OH^-']==2)
assert(u.thermodynamics.inputs[1].metadata.reaction==
 'UO2(OH)2(s) = UO2^2+ + 2 OH^-')
