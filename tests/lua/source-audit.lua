-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- Distributed under the LPPL 1.3c or any later version. See COPYING.md.

-- Optional offline source audit. No download or production parser is used.
-- Usage: texlua source-audit.lua database.lua phreeqc.dat [minteq.v4.dat llnl.dat]
local db = dofile(assert(arg[1]))
local files = {['usgs-phreeqc']=arg[2], ['usgs-minteq-v4']=arg[3], ['usgs-llnl']=arg[4]}
local lines = {}
for source, path in pairs(files) do
  lines[source] = {}
  for line in io.lines(path) do table.insert(lines[source], line) end
end
assert(lines['usgs-phreeqc'], 'phreeqc.dat is required')
local function near(a,b,context)
  assert(math.abs(a-b)<1e-9, context..': '..tostring(a)..' != '..tostring(b))
end
local function add(a,b,scale)
  for id,n in pairs(b) do a[id]=(a[id] or 0)+scale*n end
end
local function equal(a,b,context)
  for id,n in pairs(a) do near(n,b[id] or 0,context..' '..id) end
  for id,n in pairs(b) do near(n,a[id] or 0,context..' '..id) end
end
-- Translate only the upstream spelling used in the cited reactions.
local function identifier(id,record)
  if id=='H2O' then return 'H2O(l)' end
  if id=='e-' then return 'e^-' end
  if record.first:sub(-3)=='(s)' and id==record.first:sub(1,-4) then return record.first end
  local base,sign,magnitude=id:match('^(.-)([+-])(%d*)$')
  if base then return base..'^'..magnitude..sign end
  return id..'(aq)'
end
local function reaction(text,record)
  local left,right=text:match('^%s*(.-)%s*=%s*(.-)%s*$')
  assert(left and right, 'missing source equation: '..text)
  local result={}
  for index,side in ipairs({left,right}) do
    -- Charge signs have no surrounding spaces in PHREEQC syntax.
    side=side:gsub('%s+%+%s+','|')
    for term in side:gmatch('[^|]+') do
      term=term:match('^%s*(.-)%s*$')
      local number,id=term:match('^([%d%.]+)%s+(.+)$')
      id=identifier(id or term,record)
      result[id]=(result[id] or 0)+(index==1 and -1 or 1)*(tonumber(number) or 1)
    end
  end
  return result
end
local water={['H2O(l)']=-1,['H^+']=1,['OH^-']=1}
local water_found=false
for index,line in ipairs(lines['usgs-phreeqc']) do
  if line=='H2O = OH- + H+' then
    near(tonumber(lines['usgs-phreeqc'][index+1]:match('log_k%s+([%+%-]?[%d%.]+)')),-14,'water')
    water_found=true
  end
end
assert(water_found)
local count=0
for _,record in ipairs(db.list()) do
  local source=lines[record.source]
  if source then
    local rows={}
    for first,last in record.locator:gmatch('(%d+)%-(%d+)') do
      local equation
      for i=tonumber(first),tonumber(last) do
        local line=assert(source[i],'missing cited line')
        if line:find('=',1,true) and not line:match('^%s*#') then equation=line end
        local value=line:match('log_k%s+([%+%-]?[%d%.]+)')
        if value then
          rows[#rows+1]={value=tonumber(value),vector=reaction(assert(equation),record)}
        end
      end
    end
    local weights={1}
    if record.id=='phosphate-1' or record.id=='phosphate-2' or record.id=='carbonate-1' then
      weights={1,-1} -- cumulative protonation reactions occur in increasing order
    elseif record.locator:find('reversed',1,true) then weights={-1}
    elseif record.id=='cl-hypochlorite' then weights={-.5,-1} end
    assert(#rows==#weights,'unexpected source rows: '..record.id)
    local vector,value={},0
    for i,row in ipairs(rows) do
      add(vector,row.vector,weights[i]); value=value+weights[i]*row.value
    end
    if record.kind=='hydroxide formation' then
      add(vector,water,-record.hydroxide_count)
      value=value+14*record.hydroxide_count
    elseif record.kind=='solubility product' then
      local n=record.coefficients['OH^-']
      add(vector,water,n); value=value-14*n
    end
    equal(vector,record.coefficients,record.id)
    near(value,record.log_value,record.id..' log K')
    count=count+1
  end
end
local expected=50+(arg[3] and 7 or 0)+(arg[4] and 2 or 0)
assert(count==expected)
print('PASS: '..count..' source reactions, coefficient transformations and log K values')
