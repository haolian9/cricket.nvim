---@class cricket.G
---@field init_props? {[string]: string} @see the 'property list' section in `man mpv`

---@type cricket.G
local g = require("infra.G")("cricket")

---that's a dirty hack of luals annotation, as return not respect `---@type`
return g
