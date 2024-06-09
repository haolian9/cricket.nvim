local M = {}

local fs = require("infra.fs")
local iuv = require("infra.iuv")

local facts = require("cricket.facts")
local player = require("cricket.player")

local uv = vim.uv

local function resolve_track_name()
  local full = player.prop_filename()
  if full == nil then return "n/a" end
  local stem = fs.stem(full)
  return assert(string.match(stem, "^%d*[- .]*(.+)"))
end

local timer = iuv.new_timer()

function M.feed()
  uv.timer_start(timer, 0, 5 * 1000, function()
    local file = assert(io.open(facts.obs_feedfile, "w"))
    local ok, err = pcall(function() file:write(resolve_track_name()) end)
    file:close()
    assert(ok, err)
  end)
end

function M.stop() uv.timer_stop(timer) end

return M
