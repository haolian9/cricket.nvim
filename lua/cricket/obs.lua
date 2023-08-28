local fs = require("infra.fs")

local facts = require("cricket.facts")
local player = require("cricket.player")

local uv = vim.loop

local timer = uv.new_timer()

local function resolve_track_name()
  local full = player.prop_filename()
  if full == nil then return "n/a" end
  local stem = fs.stem(full)
  return assert(string.match(stem, "^%d*[- .]*(.+)"))
end

local handlers = {
  feed = function()
    uv.timer_start(timer, 0, 5 * 1000, function()
      local file = assert(io.open(facts.obs_feedfile, "w"))
      local ok, err = pcall(function() file:write(resolve_track_name()) end)
      file:close()
      if not ok then error(err) end
    end)
  end,
  stop = function() uv.timer_stop() end,
}

---@param op 'feed'|'stop'
return function(op) assert(handlers[op])() end

