local config = require("submarine.config")
local collect = require("submarine.collect")
local lsp = require("submarine.lsp")
local pickers = require("submarine.pickers")

local M = {}

---Configure submarine.nvim.
---@param opts? submarine.Config
function M.setup(opts)
	config.setup(opts)
end

---Open a picker for all exported functions of `module_name`, with hover docs from lua_ls.
---@param module_name string Name of an already-loaded module in `package.loaded`
function M.pick_functions(module_name)
	local mod = require(module_name)
	if type(mod) ~= "table" then
		vim.notify("submarine: " .. module_name .. " did not return a table", vim.log.levels.ERROR)
		return
	end
	local fns = collect.collect_fn_entries(mod)
	if #fns == 0 then
		vim.notify("submarine: no exported functions found in " .. module_name, vim.log.levels.WARN)
		return
	end
	lsp.get_luals(function(client_id)
		if not client_id then
			vim.notify("submarine: failed to start lua_ls", vim.log.levels.ERROR)
			return
		end
		lsp.fetch_docs(fns, client_id, function(results)
			vim.schedule(function()
				pickers.open_functions_picker(results, module_name)
			end)
		end)
	end)
end

---Open a picker listing all top-level loaded modules that export at least one function.
---Selecting a module calls `pick_functions` for it.
function M.pick()
	local modules = collect.collect_modules()
	if #modules == 0 then
		vim.notify("submarine: no modules found", vim.log.levels.WARN)
		return
	end
	pickers.open_modules_picker(modules, M.pick_functions)
end

return M
