local M = {}

local coreutils = require("infra.coreutils")
local fs = require("infra.fs")

---@type cricket.G
local g = require("infra.G")("cricket")

do
  local root = fs.joinpath(vim.fn.stdpath("data"), "cricket")
  assert(coreutils.mkdir(root))

  M.root = root
end

M.obs_feedfile = fs.joinpath(vim.fn.stdpath("state"), "cricket.obs")

return M

