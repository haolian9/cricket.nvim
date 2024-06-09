local M = {}

local its = require("infra.its")

local ui_select = require("beckon.select")
local player = require("cricket.player")

function M.switch()
  local devs = player.prop_audiodevices()

  local ents = its(devs) --
    :map(function(dev) return string.format("%s (%s)", dev.name, dev.description) end)
    :tolist()

  ui_select(ents, { prompt = "select audio device" }, function(_, index)
    if index == nil then return end
    local dev = devs[index]
    player.audiodevice_switch(dev.name)
  end)
end

return M
