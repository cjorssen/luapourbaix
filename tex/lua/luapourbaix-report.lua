-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Pure report presenter. All free text is escaped; numbers remain unrounded
-- in the snapshot and are rounded only by the TeX presentation callback.
local formula = (...)
local M = {}
local function escape(s)
  return (tostring(s):gsub('[\\{}%%#$&_~%^]', function(c)
    return '\\char' .. string.byte(c) .. '{}'
  end))
end
local function number(n)
  return '\\luapourbaixreportnumber{' .. string.format('%.17g', n) .. '}'
end
local function chemical(id)
  if id == 'e^-' then return '$e^-$' end
  if id == 'H2O(l)' then return '$\\hbox{H}_{2}\\hbox{O}(l)$' end
  local body = id:gsub('%(aq%)$', ''):gsub('%(s%)$', '')
  local base, magnitude, sign = body:match('^(.-)%^(%d*)([+-])$')
  local charge = base and (magnitude == '' and 1 or tonumber(magnitude)) or 0
  if sign == '-' then charge = -charge end
  return formula({formula=base or body, charge=charge,
    phase=id:match('%(s%)$') and 'solid' or 'aqueous'})
end
local function reaction(coefficients)
  local keys, left, right = {}, {}, {}
  for id in pairs(coefficients) do keys[#keys+1] = id end
  table.sort(keys)
  for _,id in ipairs(keys) do
    local c = coefficients[id]
    if c ~= 0 then
      local term = (math.abs(c)==1 and '' or number(math.abs(c)) .. ' ') .. chemical(id)
      local side = c < 0 and left or right
      side[#side+1] = term
    end
  end
  return table.concat(left, ' + ') .. ' $=$ ' .. table.concat(right, ' + ')
end
function M.render(d)
  assert(d.selection, 'luapourbaix: a report requires a selected diagram')
  local out = {}
  local function define(name, value)
    out[#out+1] = '\\expandafter\\def\\csname luapourbaixreport' .. name .. '\\endcsname{' .. value .. '}'
  end
  define('summary', escape(d.element) .. ': $T=' .. number(d.temperature) .. '\\,\\hbox{K}$; '
    .. '$s=' .. number(d.nernst_factor) .. '\\,\\hbox{V}$; '
    .. '$c_t=' .. number(d.concentration) .. '\\,\\hbox{mol/L}$; '
    .. escape(d.boundary_convention) .. '. Ideal dilute aqueous model. '
    .. 'Selection: pH ' .. number(d.selection.ph_min) .. '--' .. number(d.selection.ph_max) .. '.')
  local inputs = {}
  for i,input in ipairs(d.thermodynamics.inputs) do
    inputs[#inputs+1] = tostring(i)
    local metadata = input.metadata
    local detail = escape(input.label) .. '; ' .. escape(metadata.origin)
    if metadata.record then
      detail = detail .. '; ' .. escape(metadata.record.source) .. '; '
        .. escape(d.thermodynamics.database_sources[metadata.record.source].standard_state)
      if metadata.record.kind == 'standard potential' then
        detail = detail .. '; source $E^\\circ=' .. number(metadata.record.value) .. '\\,\\hbox{V}$'
      end
    end
    define('input' .. i, 'Input ' .. i .. ': ' .. detail .. '.\\par '
      .. reaction(input.coefficients) .. '\\par $\\log_{10}K=' .. number(input.value) .. '$.')
  end
  define('inputs', table.concat(inputs, ','))
  local final, inventory, support = {}, {}, {}
  for _,b in ipairs(d.selection.final_boundaries) do
    final[b.source] = b.name
    local intervals = {}
    for _,index in ipairs(b.segments) do
      local segment = d.selection.segments[index]
      intervals[#intervals+1] = '[' .. number(segment.ph_min) .. ', ' .. number(segment.ph_max) .. ']'
    end
    support[b.source] = '\\par Retained pH intervals: ' .. table.concat(intervals, '; ') .. '.'
  end
  for _,item in ipairs(d.selection.inventory) do inventory[item.source] = item.status end
  local boundaries = {}
  for i,b in ipairs(d.boundaries) do
    boundaries[#boundaries+1] = tostring(i)
    local t, e = b.thermodynamics, b.equation
    local equation
    if e.kind == 'potential' then
      equation = '$E/\\hbox{V}=(' .. number(e.a) .. ')\\,\\hbox{pH}+(' .. number(e.b) .. ')$'
    elseif e.kind == 'vertical' then equation = '$\\hbox{pH}=' .. number(e.ph) .. '$'
    else equation = escape(e.kind) .. ' (no finite boundary)' end
    local constants = '$\\log_{10}K=' .. number(t.log_k) .. '$'
    if t.standard_potential then
      constants = constants .. '; $E^\\circ=' .. number(t.standard_potential) .. '\\,\\hbox{V}$'
    end
    local sources = {}
    for _,s in ipairs(t.sources or {}) do
      sources[#sources+1] = number(s.coefficient) .. ' [input ' .. s.index .. ']'
    end
    define('boundary' .. i, escape(b.name) .. (final[b.name] and ' $\\to$ ' .. final[b.name] or '')
      .. ': ' .. formula(d.species_by_id[b.first]) .. ' / ' .. formula(d.species_by_id[b.second])
      .. '; ' .. escape(inventory[b.name]) .. '.\\par ' .. equation .. '.\\par '
      .. reaction(t.reaction.coefficients) .. '\\par ' .. constants .. '; ' .. escape(t.status)
      .. '.\\par Derivation of $\\log_{10}K$: ' .. table.concat(sources, ' + ') .. '.'
      .. (support[b.name] or ''))
  end
  define('boundaries', table.concat(boundaries, ','))
  local constants = {}
  local function constant(text)
    constants[#constants+1] = tostring(#constants+1)
    define('constant' .. #constants, text)
  end
  local water = d.thermodynamics.water
  if water then constant('Water: $\\log_{10}K_w=' .. number(water.log_k) .. '$; ' .. escape(water.status) .. '.') end
  for _,s in ipairs(d.species) do
    local phase = d.thermodynamics.phases[s.id]
    if phase then constant(formula(s) .. ': solid phase ' .. escape(phase) .. '.') end
    for _,item in ipairs({{'solubilities','K_s'}, {'formations','\\beta'}}) do
      local c = d.thermodynamics[item[1]][s.id]
      if c then constant(formula(s) .. ': $\\log_{10}' .. item[2] .. '=' .. number(c.log_k) .. '$; ' .. escape(c.status) .. '.') end
    end
  end
  define('constants', table.concat(constants, ','))
  local events = {}
  for i,e in ipairs(d.selection.events) do
    events[#events+1] = tostring(i)
    define('event' .. i, formula(d.species[e.species]) .. ': ' .. escape(e.reason)
      .. '; pH interval [' .. number(e.ph_min) .. ', ' .. number(e.ph_max) .. '].\\par '
      .. 'Retired limits: ' .. escape(e.lower) .. ', ' .. escape(e.upper)
      .. '; replacement: ' .. escape(e.replacement) .. '.\\par '
      .. reaction(e.reaction) .. '; $\\log_{10}K=' .. number(e.log_k) .. '$.')
  end
  define('events', table.concat(events, ','))
  return table.concat(out)
end
return M
