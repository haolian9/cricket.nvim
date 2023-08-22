local M = {}

function M.ctl() return require("cricket.ui.ctl")() end
function M.hud() return require("cricket.ui.hud")() end
function M.feed_obs(op) return require("cricket.feed_obs")(op) end

return M
