-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Curated aqueous data, offline and independent of every TeX engine service.
-- Source equations and reference conventions are retained, not homogenized.
local M = { version = "2026-10-08.1", name = "aqueous-298" }
local sources = {
  wikipedia = {
    title = "Standard electrode potential (data page)",
    url = "https://en.wikipedia.org/w/index.php?title=Standard_electrode_potential_(data_page)&oldid=1377006472",
    revision = "1377006472", accessed = "2026-10-01",
    reference = "SHE", standard_state = "unit aqueous activities; source states 1 mol/dm3",
    attribution = "Wikipedia contributors; curated numerical facts, not a copy of the table",
  },
  ["usgs-phreeqc"] = {
    title = "USGS PHREEQC phreeqc.dat, selected log_k fields",
    url = "https://github.com/usgs-coupled/phreeqc3/blob/b0b3be767158ccc3322d2c816625cf470045e67e/database/phreeqc.dat",
    revision = "b0b3be767158ccc3322d2c816625cf470045e67e",
    sha256 = "5b80d45c989cd1db7aab485e198321ba550d5902be8097c8be26d85ba03da278",
    accessed = "2026-10-01", standard_state = "molality-based aqueous activities",
    note = "Reference log_k fields only; analytical temperature expressions are not evaluated",
  },
}
-- References for classical teaching systems.
sources["usgs-minteq-v4"] = {
 title="USGS PHREEQC minteq.v4.dat, reference log_k fields",
 url="https://github.com/usgs-coupled/phreeqc3/blob/b0b3be767158ccc3322d2c816625cf470045e67e/database/minteq.v4.dat",
 revision="b0b3be767158ccc3322d2c816625cf470045e67e",
 sha256="4a48bf5c357b3da3084606a5e322426c3ab1e969dd1c86f9c62a3a7995836ca3",
 accessed="2026-10-01",standard_state="molality-based aqueous activities",
 note="Reference log_k only; no analytical temperature evaluation"}
sources["usgs-llnl"] = {
 title="USGS PHREEQC llnl.dat, thermo.com.V8.R6.230",
 url="https://github.com/usgs-coupled/phreeqc3/blob/b0b3be767158ccc3322d2c816625cf470045e67e/database/llnl.dat",
 revision="b0b3be767158ccc3322d2c816625cf470045e67e",
 sha256="1324b807f0f864806fc42df308f6ca7c5e8ce2ed8060d76351452f76beeb819b",
 accessed="2026-10-01",standard_state="molality-based aqueous activities",
 note="Reference log_k fields; dissolved oxygen is eliminated algebraically"}
sources["chromium-benchmark"] = {
 title="Computational Geosciences 19 (2015), 497-521, chromium benchmark, Table 4",
 url="https://boris-portal.unibe.ch/server/api/core/bitstreams/f01d2d61-ad0e-4baa-b1ac-ccaa870866df/content",
 doi="10.1007/s10596-014-9436-9",
 accessed="2026-10-01",standard_state="unit aqueous activities, 25 C",
 note="Amorphous chromium hydroxide acid dissolution, log K=9.35"}
sources["chlorine-thesis"] = {
 title="Chlorine Dioxide as a Potable Water Disinfectant, Table 3, p.43",
 url="https://www.collectionscanada.gc.ca/obj/thesescanada/vol2/002/MR60643.PDF",
 alternate_url="https://mspace.lib.umanitoba.ca/jspui_org/bitstream/1993/21608/1/Rak-Banville_Chlorine_Dioxide.pdf",
 accessed="2026-10-01",reference="SHE",standard_state="unit aqueous activities, 25 C",
 note="Table adapted from Lide (1999); aqueous Cl2, not chlorine gas; secondary compilation within a research thesis"}

sources["teaching-notation"] = {
 title="Traditional zincate and plumbite notation",
 url="doc/luapourbaix-manual.pdf",accessed="2026-10-01",
 standard_state="unit water activity; same aqueous activity as the hydrated notation",
 note="Model convention, not independent measured thermodynamic data"}

local defaults = {
  ["Al(OH)3(s)"] = "gibbsite", ["Fe(OH)3(s)"] = "amorphous",
  ["Fe(OH)2(s)"] = "unspecified", ["Zn(OH)2(s)"] = "epsilon",
  ["Mn(OH)2(s)"] = "pyrochroite", ["Cd(OH)2(s)"] = "unspecified",
  ["Pb(OH)2(s)"] = "unspecified",
}
local records, by_id = {}, {}
local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = copy(item) end
  return result
end
local function add(record)
  assert(not by_id[record.id], "duplicate database identifier")
  record.temperature, record.solvent = 298.15, "water"
  record.standard_state = sources[record.source].standard_state
  record.unit = record.kind == "standard potential" and "V" or "1"
  record.phases = record.phases or {}
  for _, id in ipairs({ record.first, record.second }) do
    if id:sub(-3) == "(s)" then
      defaults[id] = defaults[id] or "unspecified"
      record.phases[id] = record.phases[id] or defaults[id]
    end
  end
  record.priority = #records + 1
  records[#records + 1], by_id[record.id] = record, record
end
local function redox(id, element, oxidized, reduced, n, value, extra, count)
  local vector = { [oxidized] = -1, [reduced] = count or 1, ["e^-"] = -n }
  for key, coefficient in pairs(extra or {}) do vector[key] = coefficient end
  add { id = id, element = element, kind = "standard potential", first = oxidized,
    second = reduced, value = value, electrons = n, coefficients = vector,
    source = "wikipedia", reference = "SHE", locator = oxidized .. " / " .. reduced }
end
-- Independent couples precede the redundant Cu(II)/Cu(0) entry. Fallback
-- ordering is deterministic; table values are not asserted to close every cycle.
redox("fe-iii-ii", "Fe", "Fe^3+", "Fe^2+", 1, 0.771)
redox("fe-ii-metal", "Fe", "Fe^2+", "Fe(s)", 2, -0.44)
redox("fe-hydroxide-ii-metal", "Fe", "Fe(OH)2(s)", "Fe(s)", 2, -0.89, { ["OH^-"] = 2 })
by_id["fe-hydroxide-ii-metal"].phases = { ["Fe(OH)2(s)"] = "unspecified" }
redox("zn-ii-metal", "Zn", "Zn^2+", "Zn(s)", 2, -0.7618)
redox("al-iii-metal", "Al", "Al^3+", "Al(s)", 3, -1.662)
redox("cu-ii-i", "Cu", "Cu^2+", "Cu^+", 1, 0.159)
redox("cu-i-metal", "Cu", "Cu^+", "Cu(s)", 1, 0.52)
redox("cu-ii-metal", "Cu", "Cu^2+", "Cu(s)", 2, 0.337)
redox("ag-i-metal", "Ag", "Ag^+", "Ag(s)", 1, 0.7996)
redox("cd-ii-metal", "Cd", "Cd^2+", "Cd(s)", 2, -0.4)
redox("pb-ii-metal", "Pb", "Pb^2+", "Pb(s)", 2, -0.126)
redox("ni-ii-metal", "Ni", "Ni^2+", "Ni(s)", 2, -0.257)
redox("co-ii-metal", "Co", "Co^2+", "Co(s)", 2, -0.28)
redox("sn-iv-ii", "Sn", "Sn^4+", "Sn^2+", 2, 0.151)
redox("sn-ii-metal", "Sn", "Sn^2+", "Sn(s)", 2, -0.13)
redox("cr-iii-ii", "Cr", "Cr^3+", "Cr^2+", 1, -0.407)
redox("cr-ii-metal", "Cr", "Cr^2+", "Cr(s)", 2, -0.9)
redox("cr-dichromate-iii", "Cr", "Cr2O7^2-", "Cr^3+", 6, 1.33,
  { ["H^+"] = -14, ["H2O(l)"] = 7 }, 2)
redox("mn-ii-metal", "Mn", "Mn^2+", "Mn(s)", 2, -1.185)
redox("mg-ii-metal", "Mg", "Mg^2+", "Mg(s)", 2, -2.372)
redox("ca-ii-metal", "Ca", "Ca^2+", "Ca(s)", 2, -2.868)
redox("v-iii-ii", "V", "V^3+", "V^2+", 1, -0.26)
redox("v-ii-metal", "V", "V^2+", "V(s)", 2, -1.13)
redox("v-v-iv", "V", "VO2^+", "VO^2+", 1, 1,
  { ["H^+"] = -2, ["H2O(l)"] = 1 })

local function acid(id, element, first, second, log_k, locator, water)
  local vector = { [first] = -1, [second] = 1, ["H^+"] = 1 }
  if water then vector["H2O(l)"] = water end
  add { id = id, element = element, kind = "acidity constant", first = first,
    second = second, log_value = log_k, pka = -log_k, coefficients = vector,
    source = "usgs-phreeqc", locator = locator,
    source_log_values = { locator:find("reversed", 1, true) and -log_k or log_k } }
end
acid("phosphate-1", "P", "H3PO4(aq)", "H2PO4^-", -(21.721 - 19.553), "lines 339-347; difference of protonation log_k fields")
acid("phosphate-2", "P", "H2PO4^-", "HPO4^2-", -(19.553 - 12.346), "lines 333-341; difference of protonation log_k fields")
acid("phosphate-3", "P", "HPO4^2-", "PO4^3-", -12.346, "lines 333-334; reversed")
acid("carbonate-1", "C", "CO2(aq)", "HCO3^-", -(16.681 - 10.329), "lines 225-233; dissolved CO2, not molecular H2CO3", -1)
acid("carbonate-2", "C", "HCO3^-", "CO3^2-", -10.329, "lines 225-226; reversed")
acid("ammonium", "N", "NH4^+", "NH3(aq)", -9.252, "lines 305-306")
acid("bisulfate", "S", "HSO4^-", "SO4^2-", -1.988, "lines 251-252; reversed")
acid("sulfide-1", "S", "H2S(aq)", "HS^-", -6.994, "lines 268-269; reversed")
acid("sulfide-2", "S", "HS^-", "S^2-", -12.918, "lines 257-258")
acid("hydrogen-fluoride", "F", "HF(aq)", "F^-", -3.18, "lines 349-350; reversed")
acid("borate-source-notation", "B", "H3BO3(aq)", "H2BO3^-", -9.24, "lines 318-319; source hydration notation retained")
by_id["phosphate-1"].source_log_values = { 21.721, 19.553 }
by_id["phosphate-2"].source_log_values = { 19.553, 12.346 }
by_id["carbonate-1"].source_log_values = { 16.681, 10.329 }

-- Source hydrolysis log K: m M + n H2O = complex + n H+.
-- Convert to cumulative hydroxide formation beta using source log Kw = -14.
-- Stepwise formation constants are deliberately not labelled as cumulative.
local function hydroxide(id, element, cation, complex, m, n, hydrolysis, line)
  add { id = id, element = element, kind = "hydroxide formation", first = cation,
    second = complex, log_value = hydrolysis + 14 * n,
    coefficients = { [cation] = -m, [complex] = 1, ["OH^-"] = -n },
    source = "usgs-phreeqc", locator = "lines " .. line,
    source_log_value = hydrolysis, source_water_log_k = -14,
    source_coefficients = { [cation] = -m, [complex] = 1, ["H2O(l)"] = -n, ["H^+"] = n },
    transformation = "log beta = source hydrolysis log K - n log Kw",
    metal_count = m, hydroxide_count = n }
end
hydroxide("fe-ii-oh-1", "Fe", "Fe^2+", "FeOH^+", 1, 1, -9.5, "498-499")
hydroxide("fe-ii-oh-2", "Fe", "Fe^2+", "Fe(OH)2(aq)", 1, 2, -20.57, "547-548")
hydroxide("fe-ii-oh-3", "Fe", "Fe^2+", "Fe(OH)3^-", 1, 3, -31, "502-503")
hydroxide("fe-iii-oh-1", "Fe", "Fe^3+", "FeOH^2+", 1, 1, -2.19, "532-533")
hydroxide("fe-iii-oh-2", "Fe", "Fe^3+", "Fe(OH)2^+", 1, 2, -5.67, "536-537")
hydroxide("fe-iii-oh-3", "Fe", "Fe^3+", "Fe(OH)3(aq)", 1, 3, -12.56, "540-541")
hydroxide("fe-iii-oh-4", "Fe", "Fe^3+", "Fe(OH)4^-", 1, 4, -21.6, "543-544")
hydroxide("fe-iii-dimer", "Fe", "Fe^3+", "Fe2(OH)2^4+", 2, 2, -2.95, "550-551")
hydroxide("fe-iii-trimer", "Fe", "Fe^3+", "Fe3(OH)4^5+", 3, 4, -6.3, "553-554")
local series = {
  { "Al", 3, { -5, -10.1, -16.9, -22.7 }, { "630-631", "636-637", "641-642", "645-646" } },
  { "Cu", 2, { -8, -13.68, -26.9, -39.6 }, { "768-769", "771-772", "773-774", "775-776" } },
  { "Zn", 2, { -8.96, -16.9, -28.4, -41.2 }, { "787-788", "790-791", "792-793", "794-795" } },
  { "Cd", 2, { -10.08, -20.35, -33.3, -47.35 }, { "842-843", "845-846", "847-848", "849-850" } },
  { "Pb", 2, { -7.71, -17.12, -28.06, -39.7 }, { "904-905", "906-907", "908-909", "910-911" } },
}
for _, entry in ipairs(series) do
  local element, charge = entry[1], entry[2]
  for n, log_k in ipairs(entry[3]) do
    local q = charge - n
    local suffix = q == 0 and "(aq)" or "^" .. (math.abs(q) == 1 and "" or math.abs(q)) .. (q > 0 and "+" or "-")
    local species = element .. (n == 1 and "OH" or "(OH)" .. n) .. suffix
    hydroxide(element:lower() .. "-oh-" .. n, element, element .. "^" .. charge .. "+",
      species, 1, n, log_k, entry[4][n])
  end
end
hydroxide("mn-oh-1", "Mn", "Mn^2+", "MnOH^+", 1, 1, -10.59, "592-593")
hydroxide("mn-oh-3", "Mn", "Mn^2+", "Mn(OH)3^-", 1, 3, -34.8, "596-597")
hydroxide("mg-oh-1", "Mg", "Mg^2+", "MgOH^+", 1, 1, -11.44, "395-396")

-- Acid dissolution source: solid + n H+ = ion + n H2O.
-- Retain both the source value and the conversion to a hydroxide Ks.
local function solid(id, element, n, acid_log_k, phase, locator)
  local species, ion = element .. "(OH)" .. n .. "(s)", element .. "^" .. n .. "+"
  add { id = id, element = element, kind = "solubility product", first = species,
    second = ion, log_value = acid_log_k - 14 * n,
    coefficients = { [species] = -1, [ion] = 1, ["OH^-"] = n },
    source = "usgs-phreeqc", locator = locator,
    source_log_value = acid_log_k, source_water_log_k = -14,
    source_coefficients = { [species] = -1, [ion] = 1, ["H^+"] = -n, ["H2O(l)"] = n },
    transformation = "log Ks = source acid dissolution log K + n log Kw",
    phases = { [species] = phase } }
end
solid("al-gibbsite", "Al", 3, 8.11, "gibbsite", "Gibbsite, lines 1082-1084")
solid("al-amorphous", "Al", 3, 10.8, "amorphous", "Al(OH)3(a), lines 1087-1089")
solid("fe-iii-amorphous", "Fe", 3, 4.891, "amorphous", "Fe(OH)3(a), lines 1159-1161")
solid("mn-pyrochroite", "Mn", 2, 15.2, "pyrochroite", "Pyrochroite, lines 1192-1194")
solid("zn-epsilon", "Zn", 2, 11.5, "epsilon", "Zn(OH)2(e), lines 1289-1291")
solid("cd-hydroxide", "Cd", 2, 13.65, "unspecified", "Cd(OH)2, lines 1304-1306")
solid("pb-hydroxide", "Pb", 2, 8.15, "unspecified", "Pb(OH)2, lines 1327-1329")

-- Reaction constants below retain acid dissolution normalization. They are
-- not hydroxide-solubility shorthand and do not require new selected species.
local function supplement(id,element,first,second,logk,coefficients,source,locator,phase)
  add{id=id,element=element,first=first,second=second,kind="equilibrium constant",
    log_value=logk,coefficients=coefficients,source=source,locator=locator,
    source_log_value=logk,phases=phase}
end
defaults["Cu2O(s)"]="cuprite"
defaults["MnO2(s)"]="pyrolusite"
defaults["Cr(OH)3(s)"]="amorphous"
supplement("cu-cuprite","Cu","Cu2O(s)","Cu^+",-1.406,
 {["Cu2O(s)"]=-1,["H^+"]=-2,["Cu^+"]=2,["H2O(l)"]=1},"usgs-minteq-v4","lines 10949-10952")
supplement("cu-hydroxide","Cu","Cu(OH)2(s)","Cu^2+",8.674,
 {["Cu(OH)2(s)"]=-1,["H^+"]=-2,["Cu^2+"]=1,["H2O(l)"]=2},"usgs-minteq-v4","lines 10953-10956")
supplement("ag-oxide","Ag","Ag2O(s)","Ag^+",12.574,
 {["Ag2O(s)"]=-1,["H^+"]=-2,["Ag^+"]=2,["H2O(l)"]=1},"usgs-minteq-v4","lines 10961-10964")
supplement("ni-hydroxide","Ni","Ni(OH)2(s)","Ni^2+",12.794,
 {["Ni(OH)2(s)"]=-1,["H^+"]=-2,["Ni^2+"]=1,["H2O(l)"]=2},"usgs-minteq-v4","lines 10965-10968")
supplement("cr-amorphous","Cr","Cr(OH)3(s)","Cr^3+",9.35,
 {["Cr(OH)3(s)"]=-1,["H^+"]=-3,["Cr^3+"]=1,["H2O(l)"]=3},"chromium-benchmark","Table 4, m1, 25 C")
supplement("cr-dichromate-chromate","Cr","Cr2O7^2-","CrO4^2-",-14.56,
 {["Cr2O7^2-"]=-1,["H2O(l)"]=-1,["CrO4^2-"]=2,["H^+"]=2},"usgs-minteq-v4","lines 5000-5007; reversed")
local factor=1.380649e-23/1.602176634e-19*298.15*math.log(10)
local function logarithmic_redox(id,element,first,second,n,logk,coefficients,source,locator)
  add{id=id,element=element,first=first,second=second,kind="standard potential",
   log_value=logk,value=factor*logk/n,electrons=n,coefficients=coefficients,
   source=source,reference="SHE",locator=locator}
end
logarithmic_redox("mn-pyrolusite","Mn","MnO2(s)","Mn^2+",2,41.38,
 {["MnO2(s)"]=-1,["H^+"]=-4,["e^-"]=-2,["Mn^2+"]=1,["H2O(l)"]=2},"usgs-minteq-v4","lines 11005-11008")
logarithmic_redox("mn-permanganate","Mn","MnO4^-","Mn^2+",5,127.794,
 {["MnO4^-"]=-1,["H^+"]=-8,["e^-"]=-5,["Mn^2+"]=1,["H2O(l)"]=4},"usgs-minteq-v4","lines 470-477; reversed")
-- The source datum is E0, not log K. Preserve it when a teaching Nernst
-- factor is requested; the checker converts it using the effective factor.
add{id="cl-aqueous-metal-free",element="Cl",first="Cl2(aq)",second="Cl^-",
 kind="standard potential",value=1.396,electrons=2,
 coefficients={["Cl2(aq)"]=-1,["e^-"]=-2,["Cl^-"]=2},
 source="chlorine-thesis",reference="SHE",locator="Table 3, aqueous Cl2/Cl-, E0=1.396 V"}
logarithmic_redox("cl-hypochlorite","Cl","ClO^-","Cl^-",2,85.9951/2+15.1014,
 {["ClO^-"]=-1,["H^+"]=-2,["e^-"]=-2,["Cl^-"]=1,["H2O(l)"]=1},"usgs-llnl","lines 712-714 and 898-900; eliminate dissolved O2")
by_id["cl-hypochlorite"].source_log_values={-85.9951,-15.1014}
by_id["cl-hypochlorite"].transformation="log K = -0.5 log K(water oxidation to dissolved oxygen) - log K(hypochlorite formation)"
supplement("cl-hypochlorous-acid","Cl","HClO(aq)","ClO^-",-7.5692,
 {["HClO(aq)"]=-1,["H^+"]=1,["ClO^-"]=1},"usgs-llnl","lines 4493-4497; reversed")
by_id["cl-hypochlorous-acid"].kind="acidity constant"
by_id["cl-hypochlorous-acid"].pka=7.5692
-- Traditional teaching notation: hydration is not a new measured
-- equilibrium. With unit water activity these aliases have log K=0.
supplement("zn-traditional-zincate","Zn","ZnO2^2-","Zn(OH)4^2-",0,
 {["ZnO2^2-"]=-1,["H2O(l)"]=-2,["Zn(OH)4^2-"]=1},"teaching-notation","notation convention; hydrated data at lines 794-795")
supplement("pb-traditional-plumbite","Pb","HPbO2^-","Pb(OH)3^-",0,
 {["HPbO2^-"]=-1,["H2O(l)"]=-1,["Pb(OH)3^-"]=1},"teaching-notation","notation convention; hydrated data at lines 908-909")
for _,id in ipairs({"zn-traditional-zincate","pb-traditional-plumbite"}) do
 by_id[id].transformation="Traditional hydration notation at unit water activity; not a measured hydration constant"
end

for _,id in ipairs({"cr-dichromate-chromate","mn-permanganate","cl-hypochlorous-acid"}) do
 local r=by_id[id]
 r.source_log_value=-r.log_value
 r.source_coefficients={}
 for species,n in pairs(r.coefficients) do r.source_coefficients[species]=-n end
 r.transformation="Reverse the source reaction: log K = -source log K"
end
by_id["cl-hypochlorite"].source_reactions={
 {log_k=-85.9951,coefficients={["H2O(l)"]=-2,["O2(aq)"]=1,["H^+"]=4,["e^-"]=4}},
 {log_k=-15.1014,coefficients={["Cl^-"]=-1,["O2(aq)"]=-0.5,["ClO^-"]=1}}}

function M.get(id)
  local record = by_id[id]
  if not record then error("luapourbaix: unknown thermodynamic database entry: " .. tostring(id), 0) end
  return copy(record)
end
function M.list(element)
  local result = {}
  for _, record in ipairs(records) do
    if not element or record.element == element then result[#result + 1] = copy(record) end
  end
  return result
end
function M.sources() return copy(sources) end
function M.phase_defaults() return copy(defaults) end

function M.candidates(diagram)
  local result, phases = {}, {}
  if diagram.thermodynamic_database == "none" then return result, phases end
  for _, species in ipairs(diagram.species) do
    if species.phase == "solid" then
      phases[species.id] = species.thermodynamic_phase or defaults[species.id]
    end
  end
  for _, record in ipairs(records) do
    local eligible = record.element == diagram.element and record.temperature == diagram.temperature
    local selected = 0
    for _, id in ipairs({ record.first, record.second }) do
      if diagram.species_by_id[id] then selected = selected + 1 end
      -- Only aqueous intermediates may be added to the reaction algebra.
      if id:sub(-3) == "(s)" and not diagram.species_by_id[id] then eligible = false end
    end
    for id, phase in pairs(record.phases or {}) do
      if phases[id] ~= phase then eligible = false end
    end
    if eligible then
      local item = copy(record)
      item.selected_endpoints = selected
      result[#result + 1] = item
    end
  end
  table.sort(result, function(a, b)
    if a.selected_endpoints ~= b.selected_endpoints then return a.selected_endpoints > b.selected_endpoints end
    return a.priority < b.priority
  end)
  return result, phases
end
return M
