local M = {}

local coreutils = require("infra.coreutils")
local fs = require("infra.fs")
local mi = require("infra.mi")

do
  local root = fs.joinpath(mi.stdpath("data"), "cricket")
  assert(coreutils.mkdir(root))

  M.root = root
end

M.obs_feedfile = fs.joinpath(mi.stdpath("state"), "cricket.obs")

return M

