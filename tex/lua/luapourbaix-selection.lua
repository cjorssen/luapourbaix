-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Pure pH sweep and reconstruction of the limiting oxidation-state chain.
local M = {}
local function fail(message) error("luapourbaix: " .. message, 0) end
local function finite(x) return x == x and math.abs(x) < math.huge end
local function number(x, name)
  if type(x) == "string" then
    local s = x:match("^%s*(.-)%s*$")
    if not s:match("^[+-]?[%d%.]+[eE]?[+-]?%d*$") then
      fail(name .. " must be a finite decimal number")
    end
    x = tonumber(s)
  end
  if type(x) ~= "number" or not finite(x) then fail(name .. " must be a finite number") end
  return x
end

function M.options(raw)
  raw = raw or {}
  if type(raw) ~= "table" then fail("selection options must be a record") end
  for key in pairs(raw) do
    if key ~= "ph_min" and key ~= "ph_max" and key ~= "ph_step" then
      fail("unknown selection option: " .. tostring(key))
    end
  end
  local result = {ph_min = number(raw.ph_min, "pH min"),
    ph_max = number(raw.ph_max, "pH max"), ph_step = number(raw.ph_step or .1, "pH step")}
  if result.ph_max <= result.ph_min then fail("pH max must exceed pH min") end
  if result.ph_step <= 0 then fail("pH step must be positive") end
  local count = (result.ph_max - result.ph_min) / result.ph_step
  if not finite(count) or count > 100000 then fail("pH sweep exceeds 100000 cells; increase pH step") end
  if result.ph_min + result.ph_step == result.ph_min then fail("pH step is below numerical resolution") end
  result.ph_resolution = 32 * 2^-52 * math.max(1, math.abs(result.ph_min), math.abs(result.ph_max))
  if result.ph_step <= 2*result.ph_resolution or
      result.ph_max-result.ph_min <= 2*result.ph_resolution then
    fail("pH range or step is below numerical resolution")
  end
  return result
end

local function pair(a,b)
  if a > b then a,b = b,a end
  return a .. "\0" .. b
end
local function potential(boundary, ph)
  local q = boundary.equation
  local value = q.a * ph + q.b
  if not finite(value) then fail("non-finite potential on " .. boundary.name) end
  return value
end

-- Fixed nodes are augmented by all known changes of affine comparison signs.
local function mesh(diagram, options)
  local nodes, critical, potentials = {options.ph_min, options.ph_max}, {}, {}
  local function insert(x)
    if not finite(x) then return end
    critical[#critical+1] = x
    if x > options.ph_min and x < options.ph_max then nodes[#nodes+1] = x end
  end
  for i = 1, math.ceil((options.ph_max-options.ph_min)/options.ph_step)-1 do
    local x = options.ph_min + i * options.ph_step
    if x < options.ph_max then nodes[#nodes+1] = x end
  end
  for _, b in ipairs(diagram.boundaries) do
    if b.equation.kind == "vertical" then insert(b.equation.ph)
    elseif b.equation.kind == "potential" then potentials[#potentials+1] = b end
  end
  if #potentials * (#potentials-1)/2 > 2000000 then
    fail("too many candidate line intersections (limit 2000000)")
  end
  for i,a in ipairs(potentials) do
    for j=i+1,#potentials do
      local b = potentials[j]
      local slope = a.equation.a-b.equation.a
      local offset = b.equation.b-a.equation.b
      if not finite(slope) or not finite(offset) then fail("non-finite line intersection arithmetic") end
      if slope ~= 0 then insert(offset/slope) end
    end
  end
  table.sort(nodes)
  local unique = {}
  for _, x in ipairs(nodes) do
    if not unique[#unique] or x-unique[#unique] > options.ph_resolution then
      unique[#unique+1] = x
    elseif x == options.ph_max then unique[#unique] = x end
  end
  if #unique > 100001 then fail("refined pH sweep exceeds 100000 cells") end
  return unique, critical
end

-- Each oxidation state contributes one acid/base/solid representative at pH.
-- Persistent ties and cycles cannot be resolved by arbitrarily choosing a name.
local function representatives(diagram, lookup, ph)
  local result = {}
  for _, group in ipairs(diagram.oxidation_groups) do
    local winners = {}
    for _, a in ipairs(group.species) do
      local wins = true
      for _, b in ipairs(group.species) do
        if a.id ~= b.id then
          local boundary = lookup[pair(a.id,b.id)]
          local q, reaction = boundary.equation, boundary.thermodynamics.reaction
          local residual = q.kind == "identity" and 0 or (q.kind == "vertical" and
            q.proton_coefficient * (q.ph-ph) or q.residual)
          if (residual < 0 and a.id == reaction.first) or
             (residual > 0 and a.id == reaction.second) then wins = false; break end
        end
      end
      if wins then winners[#winners+1] = a end
    end
    if #winners ~= 1 then
      fail("non-unique same-oxidation selection at pH " .. string.format("%.17g",ph) ..
        " (oxidation number " .. group.oxidation_number ..
        "): tied species or incompatible pairwise limiting boundaries; refine the selected species/data")
    end
    result[#result+1] = winners[1]
  end
  return result
end

local function slice(diagram, lookup, ph)
  local representatives_at_ph = representatives(diagram, lookup, ph)
  local stack, events = {}, {}
  for _, species in ipairs(representatives_at_ph) do
    stack[#stack+1] = species
    while #stack >= 3 do
      local a,b,c = stack[#stack-2],stack[#stack-1],stack[#stack]
      local lower, upper = lookup[pair(a.id,b.id)],lookup[pair(b.id,c.id)]
      local lo, hi = potential(lower,ph), potential(upper,ph)
      local epsilon = 32*2^-52*math.max(1,math.abs(lo),math.abs(hi))
      if lo < hi-epsilon then break end
      events[#events+1] = {species = b.index, reduced = a.index, oxidized = c.index,
        lower = lower.name, upper = upper.name, replacement = lookup[pair(a.id,c.id)].name,
        reason = lo > hi+epsilon and "disproportionation" or "zero width"}
      table.remove(stack,#stack-1)
    end
  end
  local edges, domains = {}, {}
  for i,species in ipairs(stack) do
    local lower = i > 1 and lookup[pair(stack[i-1].id,species.id)] or nil
    local upper = i < #stack and lookup[pair(species.id,stack[i+1].id)] or nil
    domains[species.id] = {lower = lower, upper = upper}
    if upper then edges[#edges+1] = upper end
  end
  return {species = stack, edges = edges, domains = domains, events = events}
end

local function gcd(a,b)
  while b ~= 0 do a,b = b,a%b end
  return a
end
local function reaction_event(diagram, event)
  local lower = diagram.boundaries_by_name[event.lower].thermodynamics
  local upper = diagram.boundaries_by_name[event.upper].thermodynamics
  local nlo,nhi = lower.reaction.electrons,upper.reaction.electrons
  local divisor = gcd(nlo,nhi)
  local l,r = nhi/divisor,nlo/divisor
  local vector = {}
  for id,nu in pairs(lower.reaction.coefficients) do vector[id] = l*nu end
  for id,nu in pairs(upper.reaction.coefficients) do vector[id] = (vector[id] or 0)-r*nu end
  local common = 0
  for _,nu in pairs(vector) do
    if math.abs(nu) > 9007199254740991 then fail("disproportionation coefficient is too large") end
    common = gcd(common,math.abs(nu))
  end
  for id,nu in pairs(vector) do
    if nu == 0 then vector[id] = nil else vector[id] = nu/common end
  end
  event.reaction = vector
  event.lower_multiplier,event.upper_multiplier = l/common,-r/common
  event.log_k = event.lower_multiplier*lower.log_k + event.upper_multiplier*upper.log_k
  if not finite(event.log_k) then fail("non-finite disproportionation log K") end
end

function M.select(diagram, raw_options)
  if not diagram.calculation then fail("select requires calculated equations; run pourbaix/calculate first") end
  local options = M.options(raw_options)
  local nodes, critical = mesh(diagram,options)
  local lookup = {}
  for _,b in ipairs(diagram.boundaries) do lookup[pair(b.first,b.second)] = b end
  local selection = {ph_min=options.ph_min, ph_max=options.ph_max, ph_step=options.ph_step,
    ph_resolution=options.ph_resolution, nodes=nodes, cells={}, segments={}, events={},
    inventory={}, removed={}}
  local last_segment, last_event = {}, {}
  local function append_segment(boundary, first, last, kind, lower, upper)
    local previous = last_segment[boundary.name]
    if kind == "potential" and previous and previous.ph_max == first then
      previous.ph_max = last
      return previous
    end
    local segment = {name="boundary-" .. (#selection.segments+1), source=boundary.name,
      first=diagram.species_by_id[boundary.first].index,
      second=diagram.species_by_id[boundary.second].index,
      kind=kind, ph_min=first, ph_max=last, equation=boundary.equation,
      potential_min=lower, potential_max=upper}
    selection.segments[#selection.segments+1] = segment
    last_segment[boundary.name] = segment
    return segment
  end
  for i=1,#nodes-1 do
    local left,right = nodes[i],nodes[i+1]
    local ph = left+(right-left)/2
    if ph == left or ph == right then fail("pH cell has no representable interior point") end
    local current = slice(diagram,lookup,ph)
    local cell = {ph_min=left,ph_max=right,sample=ph,species={},boundaries={}}
    for _,species in ipairs(current.species) do cell.species[#cell.species+1] = species.index end
    for _,edge in ipairs(current.edges) do
      cell.boundaries[#cell.boundaries+1] = edge.name
      append_segment(edge,left,right,"potential")
    end
    for _,event in ipairs(current.events) do
      local key = event.species .. "\0" .. event.lower .. "\0" .. event.upper .. "\0" .. event.reason
      local previous = last_event[key]
      if previous and previous.ph_max == left then previous.ph_max = right
      else
        event.ph_min,event.ph_max = left,right
        reaction_event(diagram,event)
        selection.events[#selection.events+1] = event
        last_event[key] = event
      end
    end
    selection.cells[#selection.cells+1] = cell
  end

  -- Vertical candidates need potential extents, not a nonzero pH interval.
  -- Probe each side inside the closest event-free neighborhood, including at
  -- the requested range endpoints; only the boundary itself is exported.
  for _,boundary in ipairs(diagram.boundaries) do
    local q = boundary.equation
    if q.kind == "vertical" and q.ph >= options.ph_min and q.ph <= options.ph_max then
      local delta = options.ph_step/2
      for _,x in ipairs(critical) do
        local distance = math.abs(x-q.ph)
        if distance > options.ph_resolution then delta = math.min(delta,distance/2) end
      end
      if delta <= options.ph_resolution then fail("vertical neighborhood is below numerical resolution") end
      local left,right = slice(diagram,lookup,q.ph-delta),slice(diagram,lookup,q.ph+delta)
      local a,b = boundary.first,boundary.second
      local da,db = left.domains[a],right.domains[b]
      if not (da and db) then da,db = left.domains[b],right.domains[a] end
      if da and db then
        local lo = math.max(da.lower and potential(da.lower,q.ph) or -math.huge,
          db.lower and potential(db.lower,q.ph) or -math.huge)
        local hi = math.min(da.upper and potential(da.upper,q.ph) or math.huge,
          db.upper and potential(db.upper,q.ph) or math.huge)
        if lo < hi then append_segment(boundary,q.ph,q.ph,"vertical",lo,hi) end
      end
    end
  end

  -- Final identifiers belong to chemical pairs, not individual pieces.
  local function letters(n)
    local value = ""
    repeat
      n = n-1
      value = string.char(97+n%26) .. value
      n = math.floor(n/26)
    until n == 0
    return value
  end
  selection.final_boundaries, selection.final_by_name = {}, {}
  local redox, vertical = 0, 0
  for _,boundary in ipairs(diagram.boundaries) do
    local pieces = {}
    for i,segment in ipairs(selection.segments) do
      if segment.source == boundary.name then pieces[#pieces+1] = i end
    end
    if #pieces > 0 then
      local name
      if boundary.kind == "redox" then redox=redox+1; name=tostring(redox)
      else vertical=vertical+1; name=letters(vertical) end
      local final = {name=name,source=boundary.name,kind=boundary.kind,
        first=diagram.species_by_id[boundary.first].index,
        second=diagram.species_by_id[boundary.second].index,
        segments=pieces,equation=boundary.equation,thermodynamics=boundary.thermodynamics}
      selection.final_boundaries[#selection.final_boundaries+1] = final
      selection.final_by_name[name] = final
      for _,i in ipairs(pieces) do selection.segments[i].name = name end
    end
  end
  -- Coalesce strips before rendering; uniform sampling must not create seams.
  selection.domains = {}
  local last_domain = {}
  for _,cell in ipairs(selection.cells) do
    for i,index in ipairs(cell.species) do
      local lower,upper = cell.boundaries[i-1],cell.boundaries[i]
      local key = index .. "\0" .. (lower or "") .. "\0" .. (upper or "")
      local previous = last_domain[key]
      if previous and previous.ph_max == cell.ph_min then previous.ph_max = cell.ph_max
      else
        local region={species=index,lower=lower,upper=upper,ph_min=cell.ph_min,ph_max=cell.ph_max,
          kind=diagram.species[index].phase == "solid" and "existence" or "predominance"}
        selection.domains[#selection.domains+1] = region
        last_domain[key] = region
      end
    end
  end

  -- Complement of retained support, within the requested pH range. Metadata
  -- distinguishes a never-adjacent candidate from an explicit elimination event.
  for _,boundary in ipairs(diagram.boundaries) do
    local kept = {}
    for _,segment in ipairs(selection.segments) do
      if segment.source == boundary.name then kept[#kept+1] = segment end
    end
    local item = {source=boundary.name, kind=boundary.equation.kind, segments={},
      status=#kept==0 and "inactive" or "retained"}
    for _,segment in ipairs(kept) do item.segments[#item.segments+1] = segment.name end
    local function removed(first,last,lo,hi)
      selection.removed[#selection.removed+1] = {source=boundary.name,kind=item.kind,
        ph_min=first,ph_max=last,potential_min=lo,potential_max=hi}
      if #kept > 0 then item.status = "partial" end
    end
    if item.kind == "potential" then
      local start = options.ph_min
      for _,segment in ipairs(kept) do
        if segment.ph_min > start then removed(start,segment.ph_min) end
        start = segment.ph_max
      end
      if start < options.ph_max then removed(start,options.ph_max) end
    elseif item.kind == "vertical" then
      local ph=boundary.equation.ph
      if ph < options.ph_min or ph > options.ph_max then item.status="outside range"
      elseif #kept == 0 then removed(ph,ph,-math.huge,math.huge)
      else
        if kept[1].potential_min > -math.huge then removed(ph,ph,-math.huge,kept[1].potential_min) end
        if kept[1].potential_max < math.huge then removed(ph,ph,kept[1].potential_max,math.huge) end
      end
    else
      -- Identities and empty equations do not define drawable lines.
      item.status="degenerate"
    end
    selection.inventory[#selection.inventory+1] = item
  end
  diagram.selection = selection
  return diagram
end
return M
