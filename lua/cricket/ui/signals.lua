local M = {}

local augroups = require("infra.augroups")

local aug = augroups.Augroup("cricket://ui")

function M.ctl_refresh() aug:emit("user", { pattern = "cricket:ui:ctl:refresh" }) end

function M.on_ctl_refresh(callback) aug:repeats("user", { pattern = "cricket:ui:ctl:refresh", callback = callback }) end

return M
