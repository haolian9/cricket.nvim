local M = {}

local coreutils = require("infra.coreutils")
local fs = require("infra.fs")
local highlighter = require("infra.highlighter")

local api = vim.api

do
  local root = fs.joinpath(vim.fn.stdpath("state"), "cricket")
  coreutils.mkdir(root)

  M.root = root
end

do
  local ns = api.nvim_create_namespace("cricket.floatwin")
  local hi = highlighter(ns)
  if vim.go.background == "light" then
    hi("normalfloat", { fg = 8 })
  else
    hi("normalfloat", { fg = 7 })
  end

  M.floatwin_ns = ns
end
return M

