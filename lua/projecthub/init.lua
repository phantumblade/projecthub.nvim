local M = {}

--- Configura projecthub.nvim. Vedi README.md per le opzioni disponibili.
---@param opts table|nil
function M.setup(opts)
  require("projecthub.config").setup(opts)
end

--- Apre la dashboard dei progetti.
function M.open()
  require("projecthub.ui").open()
end

return M
