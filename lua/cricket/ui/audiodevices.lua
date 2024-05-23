local M = {}

local itertools = require("infra.itertools")

local player = require("cricket.player")
local puff = require("puff")

function M.switch()
  local devs = player.prop_audiodevices()

  local iter
  iter = itertools.iter(devs)
  iter = itertools.map(function(dev) return string.format("%s (%s)", dev.name, dev.description) end, iter)
  local ents = itertools.tolist(iter)

  puff.select(ents, { prompt = "select audio device" }, function(_, index)
    if index == nil then return end
    local dev = devs[index]
    player.audiodevice_switch(dev.name)
  end)
end

return M
