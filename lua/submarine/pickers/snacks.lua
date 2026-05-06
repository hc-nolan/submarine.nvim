local M = {}

---Check that Snacks.picker is available, notifying on failure.
---@return boolean
local function check()
	if not (_G.Snacks and _G.Snacks.picker) then
		vim.notify("submarine: snacks.nvim required", vim.log.levels.ERROR)
		return false
	end
	return true
end

---Open a Snacks picker listing functions with their hover documentation.
---@param results submarine.FnResult[]
---@param module_name string
function M.open_functions_picker(results, module_name)
	if not check() then
		return
	end
	table.sort(results, function(a, b)
		return a.name < b.name
	end)
	local items = vim.tbl_map(function(r)
		return { text = r.name, preview = { text = r.docs, ft = "markdown" } }
	end, results)
	Snacks.picker.pick({
		title = module_name .. " functions",
		items = items,
		format = "text",
		preview = "preview",
		confirm = function(picker, item)
			picker:close()
			local fn_name = item.text
			if not fn_name:match("^[%a_][%w_]*$") then
				vim.notify("submarine: unsafe function name, aborting: " .. fn_name, vim.log.levels.WARN)
				return
			end
			vim.fn.feedkeys(string.format(':lua require("%s").%s()', module_name, fn_name), "n")
		end,
	})
end

---Open a Snacks picker listing modules.
---Selecting a module calls `on_confirm` with the chosen module name.
---@param modules submarine.ModuleEntry[]
---@param on_confirm fun(module_name: string): nil
function M.open_modules_picker(modules, on_confirm)
	if not check() then
		return
	end
	local items = vim.tbl_map(function(m)
		return {
			text = m.name,
			name = m.name,
			preview = { text = string.format("**%s**\n\n%d exported functions", m.name, m.count), ft = "markdown" },
		}
	end, modules)
	Snacks.picker.pick({
		title = "Modules",
		items = items,
		format = "text",
		preview = "preview",
		confirm = function(picker, item)
			picker:close()
			on_confirm(item.name)
		end,
	})
end

return M
