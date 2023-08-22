local M = {}

local player = require("cricket.player")

local api = vim.api

do --init
  player.init()
  --although barrier is being used, this is still necessary for :qa!
  api.nvim_create_autocmd("vimleave", { callback = function() player.quit() end })
end

function M.ctl() return require("cricket.ui.ctl")() end
function M.hud() return require("cricket.ui.hud")() end
function M.feed_obs(op) return require("cricket.feed_obs")(op) end

return M
