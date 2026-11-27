-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Pure renderer for classification schematics, never for E-pH boundaries.
-- Chemical text comes only from the validated formula grammar. User styles
-- stay in TeX keys and are not interpreted or interpolated by Lua.
local M = {}

local function formula(species, omit_aqueous_phase)
  local result = species.formula:gsub("([A-Z][a-z]?)", "\\hbox{%1}")
    :gsub("(%d+)", "_{%1}")
  if species.charge ~= 0 then
    local magnitude = math.abs(species.charge)
    result = result .. "^{" .. (magnitude == 1 and "" or tostring(magnitude)) ..
      (species.charge > 0 and "+" or "-") .. "}"
  end
  local phase = species.phase == "solid" and "(s)" or (omit_aqueous_phase and "" or "(aq)")
  return "$" .. result .. "\\hbox{" .. phase .. "}$"
end

M.formula = formula

local roman_digits = {
  {1000, "M"}, {900, "CM"}, {500, "D"}, {400, "CD"},
  {100, "C"}, {90, "XC"}, {50, "L"}, {40, "XL"},
  {10, "X"}, {9, "IX"}, {5, "V"}, {4, "IV"}, {1, "I"},
}

local function oxidation(value, options)
  local format = options and options.oxidation_number_format or "arabic"
  assert(format == "arabic" or format == "roman",
    "luapourbaix: oxidation number format must be arabic or roman")
  local magnitude = math.abs(value)
  -- Fractional and out-of-range values retain the numeric representation.
  if format == "roman" and magnitude >= 1 and magnitude <= 3999
      and magnitude == math.floor(magnitude) then
    local digits = {}
    for _, entry in ipairs(roman_digits) do
      while magnitude >= entry[1] do
        digits[#digits + 1] = entry[2]
        magnitude = magnitude - entry[1]
      end
    end
    return (value < 0 and "-" or "+") .. "\\hbox{" .. table.concat(digits) .. "}"
  end
  return value == 0 and "0" or string.format("%+.6g", value)
end

local function increasing(options)
  local direction = options and options.acidity_direction or "decreasing"
  assert(direction == "increasing" or direction == "decreasing",
    "luapourbaix: acidity direction must be increasing or decreasing")
  return direction == "increasing"
end

function M.render(diagram, kind, options)
  if kind == "map" then return M.map(diagram, options) end
  local reverse = increasing(options)
  assert(kind == "oxidation" or kind == "acidity", "unknown classification picture")
  local lines = {}
  local function emit(value) lines[#lines + 1] = value end
  local function node(style, name, x, y, label)
    emit(string.format("\\node[%s] (%s) at (%.8g,%.8g) {%s};", style, name, x, y, label))
  end
  emit("\\scope[x=\\pgfkeysvalueof{/tikz/pourbaix/column sep}," ..
    "y=\\pgfkeysvalueof{/tikz/pourbaix/row sep}]")
  if kind == "oxidation" then
    local right = #diagram.oxidation_groups - 0.4
    emit(string.format("\\draw[pic actions,pourbaix/axis,->] (-0.4,0)--(%.8g,0);", right))
    node("pourbaix/caption,anchor=north", "-caption", (right - 0.4) / 2, -0.65,
      "\\pgfkeysvalueof{/tikz/pourbaix/oxidation caption}")
    for i, group in ipairs(diagram.oxidation_groups) do
      node("pourbaix/state,anchor=north", "-state-" .. i, i - 1, -0.12,
        "$" .. oxidation(group.oxidation_number, options) .. "$")
      emit(string.format("\\draw[pourbaix/axis] (%d,-0.08)--(%d,0.08);", i - 1, i - 1))
      for j, species in ipairs(group.species) do
        node("pic actions,pourbaix/species", "-species-" .. species.index, i - 1, j, formula(species))
      end
    end
  else
    node("pourbaix/caption,anchor=west", "-caption", -0.4, 0.8,
      "\\pgfkeysvalueof{/tikz/pourbaix/acidity caption}")
    for i, group in ipairs(diagram.oxidation_groups) do
      local y = -1.6 * (i - 1)
      node("pourbaix/state,anchor=east", "-state-" .. i, -0.55, y,
        "$" .. oxidation(group.oxidation_number, options) .. "$")
      emit(string.format("\\draw[pic actions,pourbaix/axis,->] (-0.4,%.8g)--(%.8g,%.8g);",
        y - 0.55, #group.species - 0.4, y - 0.55))
      for j, species in ipairs(group.species) do
        local x = reverse and #group.species - j or j - 1
        node("pic actions,pourbaix/species", "-species-" .. species.index, x, y, formula(species))
        if j > 1 then
          local previous = group.species[j - 1]
          local tied = species.acidity_index and species.acidity_index == previous.acidity_index
          if tied then
            node("pourbaix/state", "-tie-" .. i .. "-" .. j, reverse and x + .5 or x - .5, y, "$=$")
          end
        end
      end
    end
  end
  emit("\\endscope")
  -- A manual's verbatim/example environment may give LF catcode 12. Keep
  -- generated paths on one input line so no literal LF becomes a glyph.
  return table.concat(lines, " ")
end

-- Species map: oxidation increases upwards; acidity decreases rightwards
-- by default. This is a graph of retained pairs, not a metric E-pH diagram.
function M.map(diagram, options)
  local reverse = increasing(options)
  assert(diagram.selection, "luapourbaix: the boundary map requires selection")
  local out, positions, active = {}, {}, {}
  for _,cell in ipairs(diagram.selection.cells) do
    for _,index in ipairs(cell.species) do active[index]=true end
  end
  local function emit(s) out[#out+1]=s end
  emit("\\scope[x=\\pgfkeysvalueof{/tikz/pourbaix/column sep},y=\\pgfkeysvalueof{/tikz/pourbaix/map row sep}]")
  local maxcol=0
  for i,group in ipairs(diagram.oxidation_groups) do
    maxcol=math.max(maxcol,#group.species-1)
    emit(string.format("\\node[pourbaix/state,anchor=east] (-state-%d) at (-.5,%d) {$%s$};",
      i,i-1,oxidation(group.oxidation_number, options)))
    for j,species in ipairs(group.species) do
      local x = reverse and #group.species - j or j - 1
      positions[species.index]={x=x,y=i-1}
      local style=active[species.index] and "" or ",pourbaix/map removed species"
      emit(string.format("\\node[pic actions,pourbaix/species%s] (-species-%d) at (%d,%d) {%s};",
        style,species.index,x,i-1,formula(species)))
    end
  end
  for _,boundary in ipairs(diagram.selection.final_boundaries) do
    local a,b=positions[boundary.first],positions[boundary.second]
    local bend=math.abs(a.y-b.y)>1 and ",pourbaix/map long edge" or ""
    emit(string.format("\\draw[pic actions,pourbaix/map boundary,pourbaix/map boundary %s/.try] " ..
      "(-species-%d) to[%s] node[pourbaix/map boundary label%s] {%s} (-species-%d);",
      boundary.name,boundary.first,bend:sub(2),bend ~= "" and ",pourbaix/map long label" or "",boundary.name,boundary.second))
  end
  emit(string.format("\\draw[pourbaix/axis,->] (-.5,-.65)--(%.8g,-.65) " ..
    "node[pourbaix/caption,below,midway] {\\pgfkeysvalueof{/tikz/pourbaix/acidity caption}};",maxcol+.5))
  emit(string.format("\\draw[pourbaix/axis,->] (-1,-.25)--(-1,%.8g) " ..
    "node[pourbaix/caption,above,sloped,midway] {\\pgfkeysvalueof{/tikz/pourbaix/oxidation caption}};",
    math.max(.5,#diagram.oxidation_groups-.5)))
  emit("\\endscope")
  return table.concat(out," ")
end
return M
