-- Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
-- This file is part of luapourbaix.
-- Distributed under the LPPL 1.3c or, at your option, any later version.
-- Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

-- Pure equation assembly from checked reactions and supplied log activities.
local M = {}
local function finite(value, name)
  if value ~= value or math.abs(value) == math.huge then
    error("luapourbaix: non-finite boundary coefficient: " .. name, 0)
  end
  return value == 0 and 0 or value
end
local function decimal(value)
  return string.format("%.17g", value)
end

-- log_activities returns a table indexed by the two endpoint identifiers.
-- Water has unit activity and pH is -log10(a(H+)). The caller owns the copy.
function M.calculate(diagram, log_activities)
  if not (diagram.thermodynamics and diagram.thermodynamics.checked) then
    error("luapourbaix: calculate requires a checked diagram; run pourbaix/check first", 0)
  end
  local factor = finite(diagram.nernst_factor or (1.380649e-23 / 1.602176634e-19) *
    diagram.temperature * math.log(10), "Nernst factor")
  for _, boundary in ipairs(diagram.boundaries) do
    local data = boundary.thermodynamics
    local reaction = data.reaction
    local activities = log_activities(diagram, boundary)
    local offset = 0
    for _, id in ipairs({reaction.first, reaction.second}) do
      offset = offset + reaction.coefficients[id] * activities[id]
    end
    offset = finite(offset, boundary.name .. " log Q offset")
    local proton = reaction.coefficients["H^+"] or 0
    local result = {log_q_offset = offset, proton_coefficient = proton,
      log_activities = activities}
    if reaction.electrons > 0 then
      result.kind = "potential"
      result.a = finite(factor * proton / reaction.electrons, boundary.name .. " a")
      result.b = finite(factor * (data.log_k - offset) / reaction.electrons,
        boundary.name .. " b")
      result.expression = "(" .. decimal(result.a) .. ")*x+(" .. decimal(result.b) .. ")"
      result.text = "E = (" .. decimal(result.a) .. ")*pH+(" .. decimal(result.b) .. ")"
    elseif proton ~= 0 then
      result.kind = "vertical"
      result.ph = finite((offset - data.log_k) / proton, boundary.name .. " pH")
      result.expression = decimal(result.ph)
      result.text = "pH = " .. result.expression
    else
      -- A pH-independent reaction is not a vertical line. The closure's
      -- log-K tolerance also defines numerical indistinguishability here.
      result.residual = finite(offset - data.log_k, boundary.name .. " residual")
      result.kind = math.abs(result.residual) <= diagram.thermodynamics.tolerance
        and "identity" or "empty"
      result.text = result.kind == "identity" and "all pH and E" or "no solution"
    end
    boundary.equation = result
  end
  return diagram
end
return M
