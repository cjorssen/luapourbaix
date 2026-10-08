-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- Distributed under the LPPL 1.3c or any later version. See COPYING.md.

-- Independent catalogue cycle audit, with distinct columns for solid phases.
package.path=assert(arg[1]):match('^(.*[/\\])')..'?.lua;'..package.path
local core=dofile(arg[1])
local factor=1.380649e-23/1.602176634e-19*298.15*math.log(10)
local basis,cycles={},{}
local function near(a,b) assert(math.abs(a-b)<1e-9,tostring(a)..' != '..tostring(b)) end
local function insert(record)
  local vector={}
  for id,n in pairs(record.coefficients) do
    local phase=record.phases and record.phases[id]
    vector[id..(phase and '@'..phase or '')]=n
  end
  local value=record.log_value or record.electrons*record.value/factor
  while true do
    local keys={}
    for id,n in pairs(vector) do if math.abs(n)>1e-10 then keys[#keys+1]=id end end
    table.sort(keys)
    local pivot=keys[1]
    if not pivot then cycles[record.id]=value; return end
    local n=vector[pivot]
    if basis[pivot] then
      for id,c in pairs(basis[pivot].vector) do vector[id]=(vector[id] or 0)-n*c end
      value=value-n*basis[pivot].value
    else
      for id,c in pairs(vector) do vector[id]=c/n end
      basis[pivot]={vector=vector,value=value/n}; return
    end
  end
end
insert{id='water',coefficients={['H2O(l)']=-1,['H^+']=1,['OH^-']=1},log_value=-14}
for _,record in ipairs(core.database.list()) do insert(record) end
local count=0
for id,residual in pairs(cycles) do
  count=count+1
  assert(id=='cu-ii-metal','unreviewed dependent catalogue reaction: '..id)
  near(residual,(2*.337-.159-.520)/factor)
end
assert(count==1,'review the catalogue cycle inventory')
-- A source potential remains a potential when the teaching factor changes.
-- A source log K remains log K; its equivalent potential changes with s.
for _,s in ipairs({factor,.06}) do
  for _,case in ipairs({{'Cl','Cl2(aq),Cl^-',1.396},
      {'Mn','MnO2(s),Mn^2+',s*41.38/2}}) do
    local d=core.check(core.declare{element=case[1],species=case[2],temperature=298.15,
      constants={},concentration=.01,boundary_convention='equal concentrations',nernst_factor=s})
    near(d.boundaries[1].thermodynamics.standard_potential,case[3])
  end
end
print('PASS: phase-aware catalogue cycles and potential/log-K source semantics')
