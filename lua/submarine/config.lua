---@class submarine.Config
---@field luals_cmd string[] Command to start lua-language-server
---@field root_dir string Root directory for the lua_ls workspace

---@class submarine.ConfigModule : submarine.Config
---@field setup fun(opts?: submarine.Config): nil
local M = {
	luals_cmd = { "lua-language-server" },
	root_dir = vim.fn.stdpath("config") --[[@as string]],
}

---Merge user options into the active config.
---@param opts? submarine.Config
function M.setup(opts)
	M = vim.tbl_deep_extend("force", M, opts or {})
end

return M
