--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

-- Experimental EDTF parser based on lpeg

local edtf = {}

local lpeg = require("lpeg")

function edtf.parse(str)
  ---@diagnostic disable: codestyle-check
  local digit = lpeg.R("09") + lpeg.P"X"
  local hyphen = lpeg.P("-")
  local colon = lpeg.P(":")
  local year = lpeg.C(hyphen^-1 * digit^1^-4) +
    lpeg.P"Y" * lpeg.C(hyphen^-1 * digit^5)
  local month = lpeg.C(digit * digit)
  local day = lpeg.C(digit * digit)
  local date = lpeg.Ct(year * (hyphen * month)^-1 * (hyphen * day)^-1)

  local time = digit * digit * colon * digit * digit * colon * digit * digit * colon
  local time_zone = lpeg.P"Z" + lpeg.S("+-") * digit * digit * (colon * digit * digit)
  local date_time = lpeg.Ct(date * (lpeg.P"T" * time * time_zone^-1)^-1)

  local date_range = lpeg.Ct(date * lpeg.P"/" * date)
  local date_parts = lpeg.Cg(date_range + date_time, "date-parts")
  local circa = lpeg.Cg(lpeg.S"?~%" / function () return true end, "circa")

  local edtf_date = lpeg.Ct(date_parts * (circa)^-1) / function (d)
    for _, range_part in ipairs(d['date-parts']) do
      for i, date_part in ipairs(range_part) do
        if string.match(date_part, "X") then
          d.circa = true
          date_part = string.gsub(date_part, "X", "0")
        end
        date_part = tonumber(date_part)
        if date_part == 0 then
          date_part = nil
        end
        range_part[i] = date_part
      end
    end
    return d
  end
  ---@diagnostic enable: codestyle-check
  local res = lpeg.match(edtf_date, str)
  return res
end

return edtf
