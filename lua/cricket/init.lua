local M = {}

function M.ctl() return require("cricket.ui.ctl").floatwin() end
function M.hud() return require("cricket.ui.hud").permanent() end
function M.obs(op) return require("cricket.obs")(op) end

return M
