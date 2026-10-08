-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Engine-specific bridge; this is the only module allowed to access TeX.
local function find_file(name)
  if resolvers and resolvers.findfile then
    local path = resolvers.findfile(name)
    if path and path ~= "" then
      return path
    end
  end
  if kpse and kpse.find_file then
    return kpse.find_file(name, "tex")
  end
end

local path = assert(find_file("luapourbaix.lua"),
  "luapourbaix: cannot locate luapourbaix.lua")
local database = dofile(assert(find_file("luapourbaix-database.lua"),
  "luapourbaix: cannot locate thermodynamic database"))
local closure = assert(loadfile(assert(find_file("luapourbaix-thermodynamics.lua"),
  "luapourbaix: cannot locate thermodynamic closure module")))(database)
local equations = dofile(assert(find_file("luapourbaix-equations.lua"),
  "luapourbaix: cannot locate boundary equation module"))
local selection = dofile(assert(find_file("luapourbaix-selection.lua"),
  "luapourbaix: cannot locate selection module"))
local core = assert(loadfile(path))(closure, equations, selection)
local renderer = dofile(assert(find_file("luapourbaix-tikz.lua"),
  "luapourbaix: cannot locate classification renderer"))

local plotter = assert(loadfile(assert(find_file("luapourbaix-plot.lua"),
  "luapourbaix: cannot locate plot renderer")))(renderer.formula)
local reporter = assert(loadfile(assert(find_file("luapourbaix-report.lua"),
  "luapourbaix: cannot locate report presenter")))(renderer.formula)

texio.write_nl("log", "luapourbaix " .. core.version .. " loaded")

local registry = core.new_registry()
local water = dofile(assert(find_file("luapourbaix-water.lua")))
local ticks = dofile(assert(find_file("luapourbaix-ticks.lua")))
local drafts = {}
local M = { core = core, get = registry.get }

-- Read macro replacement text, not expanded text and never executable Lua.
-- PGF's .expanded handler is the user's explicit opt-in to TeX expansion.
local function read(name)
  return token.get_macro("luapourbaix" .. name) or ""
end

local function report(message)
  tex.error(tostring(message), {
    "The declaration was not registered. Existing diagrams are unchanged.",
    "Check required keys, formula syntax, references, and numerical values.",
  })
end

function M.begin_declaration()
  drafts[#drafts + 1] = { constants = {}, species_data = {}, boundary_names = {} }
end

function M.invalidate()
  if drafts[#drafts] then
    drafts[#drafts].invalid = true
  end
end

function M.add_potential()
  local constants = drafts[#drafts].constants
  constants[#constants + 1] = { kind = "standard potential",
    oxidized = read("oxidized"), reduced = read("reduced"), value = read("value") }
end

function M.add_solubility()
  local constants = drafts[#drafts].constants
  constants[#constants + 1] = { kind = "solubility product",
    solid = read("solid"), reaction = read("hasreaction") == "1" and read("reaction") or nil, value = read("value"), log_value = read("logvalue") }
end

function M.add_equilibrium()
  local constants = drafts[#drafts].constants
  constants[#constants + 1] = { kind = "equilibrium constant", first = read("first"),
    second = read("second"), reaction = read("hasreaction") == "1" and read("reaction") or nil, value = read("value"), log_value = read("logvalue") }
end

function M.add_water()
  local constants = drafts[#drafts].constants
  constants[#constants + 1] = { kind = "water ion product",
    value = read("value"), log_value = read("logvalue") }
end

function M.add_species_data()
  local entries = drafts[#drafts].species_data
  entries[#entries + 1] = { species = read("dataspecies"),
    oxidation_number = read("oxidation"), acidity_rank = read("acidityrank"),
    thermodynamic_phase = read("phase") }
end

function M.add_boundary_name()
  local entries = drafts[#drafts].boundary_names
  entries[#entries + 1] = { first = read("first"), second = read("second"),
    name = read("boundaryname") }
end

function M.finish_declaration()
  local draft = table.remove(drafts)
  token.set_macro("luapourbaixresult", "")
  if draft.invalid then
    return
  end
  draft.name = read("name")
  draft.element = read("element")
  draft.species = read("species")
  draft.concentration = read("concentration")
  draft.temperature = read("temperature")
  draft.nernst_factor = read("nernstfactor")
  draft.activity_model = read("activitymodel")
  draft.thermodynamic_tolerance = read("tolerance")
  draft.thermodynamic_database = read("database")
  draft.boundary_convention = read("convention")
  draft.boundary_labels = { vertical_prefix = read("verticalprefix"),
    redox_prefix = read("redoxprefix"), suffix = read("boundarysuffix") }
  if read("hasconstants") ~= "1" then
    draft.constants = nil
  end
  local operation = read("buildmode") == "1" and "build" or "add"
  local options = {ph_min=read("phmin"),ph_max=read("phmax"),ph_step=read("phstep")}
  local ok, handle, diagram = pcall(registry[operation], draft, options)
  if not ok then
    report(handle)
    return
  end
  -- Only validated names and decimal handles travel back to TeX.
  token.set_macro("luapourbaixname", diagram.name or "")
  token.set_macro("luapourbaixresult", tostring(handle))
end

function M.resolve_name()
  token.set_macro("luapourbaixresult", "")
  local name = read("lookupname"):match("^%s*(.-)%s*$")
  if not name:match("^[A-Za-z][A-Za-z0-9_.:-]*$") then
    tex.error("luapourbaix: invalid diagram name", { "Use a literal declared name." })
    return
  end
  local handle = token.get_macro("luapourbaix@named@" .. name)
  if not handle then
    tex.error("luapourbaix: unknown diagram name: " .. name,
      { "Declare it first, in this TeX scope or an enclosing scope." })
    return
  end
  token.set_macro("luapourbaixresult", handle)
end

function M.check_diagram()
  local handle = read("checkhandle")
  token.set_macro("luapourbaixresult", "")
  local options
  if read("operation") == "select" then
    options = {ph_min=read("phmin"),ph_max=read("phmax"),ph_step=read("phstep")}
  end
  local ok, result, diagram = pcall(registry[read("operation")], handle, options)
  if not ok then
    tex.error(tostring(result), { "No result snapshot was registered. Existing diagrams are unchanged.",
      "Check the diagnostic and complete the required preceding stages." })
    return
  end
  token.set_macro("luapourbaixresult", tostring(result))
  if read("checkbyname") == "1" then token.set_macro("luapourbaixname", diagram.name or "") end
end

function M.export_data()
  local handle = token.get_macro("pgfplotslastpourbaix")
  local diagram = registry.get(handle)
  local prefix = "/pgfplots/pourbaix/data/" .. handle .. "/"
  local output = {}
  local function emit(key, value)
    if value == nil then return end
    if type(value) == "number" then value = string.format("%.17g", value) end
    output[#output + 1] = "\\pgfkeyssetvalue{" .. prefix .. key .. "}{" .. value .. "}"
  end
  emit("checked", "true")
  emit("calculated", diagram.calculation and "true" or "false")
  emit("selected", diagram.selection and "true" or "false")
  emit("activity model", diagram.activity_model)
  emit("nernst factor", diagram.nernst_factor)
  emit("nernst factor source", diagram.nernst_factor_source)
  if diagram.calculation then emit("standard concentration", 1) end
  emit("database", diagram.thermodynamics.database)
  emit("database version", diagram.thermodynamics.database_version)
  emit("database consulted", diagram.thermodynamics.database_consulted and "true" or "false")
  for index, input in ipairs(diagram.thermodynamics.inputs) do
    local path, metadata = "input " .. index .. "/", input.metadata
    emit(path .. "origin", metadata.origin)
    emit(path .. "log K", input.value)
    -- Validated chemical grammar contains no executable TeX control sequences.
    if metadata.reaction then emit(path .. "reaction", "\\detokenize{" .. metadata.reaction .. "}") end
    local participants = {}
    for id in pairs(input.coefficients) do participants[#participants + 1] = id end
    table.sort(participants)
    for _, id in ipairs(participants) do
      emit(path .. "coefficient/" .. id, input.coefficients[id])
    end
    if metadata.record then
      emit(path .. "database id", metadata.record.id)
      emit(path .. "source id", metadata.record.source)
      emit(path .. "temperature", metadata.record.temperature)
      emit(path .. "kind", metadata.record.kind)
    end
  end
  for _, boundary in ipairs(diagram.boundaries) do
    local data, path = boundary.thermodynamics, boundary.name .. "/"
    local equation = boundary.equation
    if equation then
      emit(path .. "equation type", equation.kind)
      emit(path .. "equation", equation.text)
      emit(path .. "expression", equation.expression)
      emit(path .. "residual", equation.residual)
      emit(path .. "a", equation.a)
      emit(path .. "b", equation.b)
      emit(path .. "pH", equation.ph)
      emit(path .. "log Q offset", equation.log_q_offset)
      emit(path .. "proton coefficient", equation.proton_coefficient)
    end
    emit(path .. "log K", data.log_k)
    emit(path .. "standard potential", data.standard_potential)
    emit(path .. "equilibrium constant", data.equilibrium_constant)
    emit(path .. "pKa", data.pka)
    emit(path .. "electrons", data.reaction.electrons)
    emit(path .. "status", data.status)
    for _, source in ipairs(data.sources) do
      emit(path .. "source " .. source.index, source.coefficient)
    end
  end
  if diagram.thermodynamics.water then
    emit("water/log K", diagram.thermodynamics.water.log_k)
    emit("water/ion product", diagram.thermodynamics.water.value)
    emit("water/status", diagram.thermodynamics.water.status)
  end
  for _, species in ipairs(diagram.species) do
    local path = "species " .. species.index .. "/"
    emit(path .. "thermodynamic phase", diagram.thermodynamics.phases[species.id])
    local formation = diagram.thermodynamics.formations[species.id]
    if formation then
      emit(path .. "log beta", formation.log_k)
      emit(path .. "beta", formation.value)
      emit(path .. "formation status", formation.status)
    end
    local data = diagram.thermodynamics.solubilities[species.id]
    if data then
      emit(path .. "log solubility product", data.log_k)
      emit(path .. "solubility product", data.value)
      emit(path .. "status", data.status)
    end
  end
  if diagram.selection then
    local selection = diagram.selection
    local root = "selection/"
    local function extent(path, record)
      emit(path .. "pH min", record.ph_min)
      emit(path .. "pH max", record.ph_max)
      for _, side in ipairs({"min", "max"}) do
        local value = record["potential_" .. side]
        if value ~= nil then
          emit(path .. "potential " .. side, value == -math.huge and "-infinity" or
            value == math.huge and "infinity" or value)
        end
      end
    end
    extent(root, selection)
    emit(root .. "pH step", selection.ph_step)
    emit(root .. "pH resolution", selection.ph_resolution)
    emit(root .. "final boundary count", #selection.final_boundaries)
    emit(root .. "domain count", #selection.domains)
    for _,boundary in ipairs(selection.final_boundaries) do
      local path="final/" .. boundary.name .. "/"
      emit(path .. "source",boundary.source)
      emit(path .. "first species",boundary.first)
      emit(path .. "second species",boundary.second)
      emit(path .. "segment count",#boundary.segments)
      emit(path .. "equation type",boundary.equation.kind)
      emit(path .. "equation",boundary.equation.text)
      emit(path .. "expression",boundary.equation.expression)
      emit(path .. "a",boundary.equation.a)
      emit(path .. "b",boundary.equation.b)
      emit(path .. "pH",boundary.equation.ph)
      emit(path .. "log K",boundary.thermodynamics.log_k)
      emit(path .. "standard potential",boundary.thermodynamics.standard_potential)
      emit(path .. "equilibrium constant",boundary.thermodynamics.equilibrium_constant)
      for i,index in ipairs(boundary.segments) do emit(path .. "segment " .. i,index) end
    end
    for i,domain in ipairs(selection.domains) do
      local path=root .. "domain " .. i .. "/"
      extent(path,domain)
      emit(path .. "species",domain.species)
      emit(path .. "kind",domain.kind)
      emit(path .. "lower source",domain.lower)
      emit(path .. "upper source",domain.upper)
    end
    emit(root .. "cell count", #selection.cells)
    emit(root .. "segment count", #selection.segments)
    emit(root .. "event count", #selection.events)
    emit(root .. "removed count", #selection.removed)
    emit(root .. "candidate count", #selection.inventory)
    for i,segment in ipairs(selection.segments) do
      local path = root .. "segment " .. i .. "/"
      extent(path,segment)
      emit(path .. "name", segment.name)
      emit(path .. "source", segment.source)
      emit(path .. "first species", segment.first)
      emit(path .. "second species", segment.second)
      emit(path .. "equation type", segment.kind)
      emit(path .. "equation", segment.equation.text)
      emit(path .. "expression", segment.equation.expression)
      emit(path .. "a", segment.equation.a)
      emit(path .. "b", segment.equation.b)
      emit(path .. "pH", segment.equation.ph)
    end
    for i,event in ipairs(selection.events) do
      local path = root .. "event " .. i .. "/"
      extent(path,event)
      emit(path .. "species", event.species)
      emit(path .. "reduced species", event.reduced)
      emit(path .. "oxidized species", event.oxidized)
      emit(path .. "lower source", event.lower)
      emit(path .. "upper source", event.upper)
      emit(path .. "replacement source", event.replacement)
      emit(path .. "reason", event.reason)
      emit(path .. "log K", event.log_k)
      emit(path .. "lower multiplier", event.lower_multiplier)
      emit(path .. "upper multiplier", event.upper_multiplier)
      for _,species in ipairs(diagram.species) do
        emit(path .. "species " .. species.index .. " coefficient", event.reaction[species.id])
      end
      emit(path .. "proton coefficient", event.reaction["H^+"] or 0)
      emit(path .. "water coefficient", event.reaction["H2O(l)"] or 0)
    end
    for i,item in ipairs(selection.inventory) do
      local path=root .. "candidate " .. i .. "/"
      emit(path .. "source",item.source)
      emit(path .. "status",item.status)
      emit(path .. "segment count",#item.segments)
    end
    for i,item in ipairs(selection.removed) do
      local path=root .. "removed " .. i .. "/"
      extent(path,item)
      emit(path .. "source",item.source)
      emit(path .. "equation type",item.kind)
    end
  end
  -- Paths and formulas use validated chemical/name grammars. Numeric values
  -- are finite; explicit reaction text is wrapped in detokenize. No user text
  -- becomes an executable control sequence in the generated definitions.
  -- Adjacent definitions need no separator. Spaces here become visible glue
  -- when the check runs in horizontal mode (including manual examples).
  tex.sprint(table.concat(output, ""))
end

function M.split_pair_address()
  local first,second=read("pairaddressvalue"):match("^([^|]+)|([^|]+)$")
  if not first or not first:match("%S") or not second:match("%S") then
    M.invalidate()
    token.set_macro("luapourbaixpairvalid","0")
    tex.error("luapourbaix: a pair key requires exactly two species separated by |",
      {"Use oxidized|reduced for a standard reduction potential, first|second for an equilibrium constant."})
    return
  end
  token.set_macro("luapourbaixpairvalid","1")
  token.set_macro("luapourbaixpairfirst",first)
  token.set_macro("luapourbaixpairsecond",second)
end

function M.prepare_report()
  local ok, output = pcall(function()
    return reporter.render(registry.get(read("reporthandle")))
  end)
  if not ok then
    token.set_macro("luapourbaixreportvalid", "0")
    tex.error(tostring(output), {"Finalize the diagram before requesting a report."})
    return
  end
  -- Only fixed commands, escaped text and finite numeric literals are emitted.
  -- Styles stay as TeX tokens; normal format catcodes consume these definitions.
  tex.sprint(output)
end

function M.prepare_water()
  token.set_macro("luapourbaixwaterresult", "")
  local ok, result = pcall(function()
    local temperature=read("watertemperature")
    local factor=read("waternernstfactor")
    local inherited_factor
    if read("waterdiagram")~="" then
      local handle=token.get_macro("luapourbaix@named@"..read("waterdiagram"))
      if not handle then error("luapourbaix: unknown water temperature diagram",0) end
      local diagram=registry.get(handle)
      local inherited=diagram.temperature
      inherited_factor=diagram.nernst_factor
      if factor=="" then factor=inherited_factor end
      if temperature~="" and tonumber(temperature)~=inherited then
        error("luapourbaix: water and diagram temperatures disagree",0)
      end
      temperature=inherited
    end
    local result=water.compute{temperature=temperature,nernst_factor=factor,
      hydrogen_pressure=read("waterhydrogenpressure"),
      oxygen_pressure=read("wateroxygenpressure"),oxygen_standard_potential=read("wateroxygenstandardpotential")}
    if inherited_factor and result.nernst_factor~=inherited_factor then
      error("luapourbaix: water and diagram Nernst factors disagree",0)
    end
    return result
  end)
  if not ok then tex.error(tostring(result),{"Previous water data were preserved."});return end
  local out={}
  for _,k in ipairs({"temperature","nernst_factor","hydrogen_pressure","oxygen_pressure","oxygen_standard_potential","a","hydrogen_b","oxygen_b"}) do
    out[#out+1]="\\pgfkeyssetvalue{/pgfplots/pourbaix/water/data/"..k:gsub("_"," ").."}{"..string.format("%.17g",result[k]).."}"
  end
  out[#out+1]="\\pgfkeyssetvalue{/pgfplots/pourbaix/water/data/reference}{SHE}"
  out[#out+1]="\\pgfkeyssetvalue{/pgfplots/pourbaix/water/data/standard pressure}{1}"
  for _,id in ipairs({"hydrogen","oxygen"}) do
    out[#out+1]="\\pgfkeyssetvalue{/pgfplots/pourbaix/water/data/"..id.." expression}{("..string.format("%.17g",result.a)..")*x+("..string.format("%.17g",result[id.."_b"])..")}"
  end
  -- Validated numbers and fixed key paths only. Assignment occurs after the
  -- temporary option group closes, in the caller's TeX scope.
  token.set_macro("luapourbaixwaterresult",table.concat(out))
end

-- PGFPlots 1.18 stores these public-key values in macros rather than .initial
-- keys. Read only; all updates are through the public extra ticks keys in TeX.
local function tick_output(x,y,root)
  x=ticks.additional(x,token.get_macro("pgfplots@extra@xtick"))
  y=ticks.additional(y,token.get_macro("pgfplots@extra@ytick"))
  return "\\luapourbaixcaptureticks{"..x.."}{"..y.."}{"..root.."}"
end
function M.plot_water()
  local ok,out=pcall(function()
    local d={a=read("watera"),hydrogen_b=read("waterhydrogenb"),oxygen_b=read("wateroxygenb")}
    local box={xmin=read("plotxmin"),xmax=read("plotxmax"),ymin=read("plotymin"),ymax=read("plotymax")}
    local output=water.render(d,box)
    local y=ticks.water(d,box,read("wateryticks"))
    return tick_output({},y,"/pgfplots/pourbaix/water")..output
  end)
  if not ok then tex.error(tostring(out),{"No water plots were submitted."});return end
  tex.sprint(out)
end

function M.plot_diagram()
  local ok, output = pcall(function()
    local function key(name) return token.get_macro("luapourbaixplot" .. name) or "" end
    local handle = key("handle")
    if handle == "" then
      M.resolve_name()
      handle = read("result")
      if handle == "" then return "" end
    end
    local options = {xmin=key("xmin"),xmax=key("xmax"),ymin=key("ymin"),ymax=key("ymax")}
    options.coloring=key("coloring")
    options.palette=key("palette")
    options.label_mode=key("labelmode")
    options.label_placement=key("labelplacement")
    options.letter_species=key("letterspecies")
    options.domains={}
    options.boundary_ids={}
    for i=1,tonumber(read("boundarycount")) do options.boundary_ids[i]=read("boundaryid"..i) end
    local diagram=registry.get(handle)
    local function species(id) return core.parse_species(id,diagram.element).id end
    for i=1,tonumber(read("domaincount")) do
      options.domains[i]={species=species(read("domainspecies"..i)),at=read("domainat"..i)}
    end
    if options.letter_species~="" then
      local ids={}
      for id in (options.letter_species..","):gmatch("(.-),") do ids[#ids+1]=species(id) end
      options.letter_species=table.concat(ids,",")
    end
    for _,name in ipairs({"domain_fills","domain_labels","boundaries","boundary_labels",
      "removed_boundaries","removed_domains","provisional_boundaries","provisional_labels"}) do
      options[name] = key((name:gsub("_", "")))
    end
    local output,geometry=plotter.render(diagram, options)
    local x,y=ticks.element(diagram,geometry,{x=key("xticks"),y=key("yticks")})
    return tick_output(x,y,"/pgfplots/pourbaix/plot")..output
  end)
  if not ok then
    tex.error(tostring(output), {"No plots were submitted. Finalize the diagram first and supply explicit decimal xmin, xmax, ymin, ymax."})
    return
  end
  tex.sprint(output)
end

function M.draw_classification()
  local ok, result = pcall(function()
    local handle = read("drawhandle")
    if handle == "" then
      local name = read("lookupname"):match("^%s*(.-)%s*$")
      if not name:match("^[A-Za-z][A-Za-z0-9_.:-]*$") then
        error("luapourbaix: provide a diagram name or a captured handle", 0)
      end
      handle = token.get_macro("luapourbaix@named@" .. name)
      if not handle then error("luapourbaix: unknown diagram name: " .. name, 0) end
    end
    return renderer.render(registry.get(handle), read("picturekind"),
      {acidity_direction=read("aciditydirection"),
       oxidation_number_format=read("oxidationnumberformat")})
  end)
  if not ok then
    tex.error(tostring(result), { "No classification picture was generated." })
    return
  end
  -- Fixed TeX commands and validated formula characters only. TikZ consumes
  -- the resulting paths inside its pic group, using the current format's
  -- normal catcodes (including TikZ's semicolon handling).
  tex.sprint(result)
end

return M
