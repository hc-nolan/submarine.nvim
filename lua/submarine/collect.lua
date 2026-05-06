local M = {}

---@class submarine.FnEntry
---@field names string[] All exported keys that point to this function
---@field fn function The function itself
---@field info debuginfo debug.getinfo result (fields: source, linedefined)

---@class submarine.FnResult
---@field name string Display name (aliases joined with " / ")
---@field docs string Markdown documentation string

---@class submarine.ModuleEntry
---@field name string Module name
---@field count integer Number of exported functions

---Collect all file-defined exported functions from `mod`, deduplicating by
---`(source, linedefined)` so aliased functions are grouped.
---@param mod table
---@return submarine.FnEntry[]
function M.collect_fn_entries(mod)
	---@type table<string, submarine.FnEntry>
	local fn_map = {}
	for key, val in pairs(mod) do
		if type(val) == "function" then
			local info = debug.getinfo(val, "S")
			if info.source:sub(1, 1) == "@" then
				local dedup_key = info.source .. ":" .. info.linedefined
				if not fn_map[dedup_key] then
					fn_map[dedup_key] = { names = {}, fn = val, info = info }
				end
				fn_map[dedup_key].names[#fn_map[dedup_key].names + 1] = key
			end
		end
	end
	return vim.tbl_values(fn_map)
end

---Collect top-level loaded modules that export at least one function.
---@return submarine.ModuleEntry[]
function M.collect_modules()
	---@type submarine.ModuleEntry[]
	local modules = {}
	for name, val in pairs(package.loaded) do
		if type(name) == "string" and not name:find(".", 1, true) and type(val) == "table" then
			local count = 0
			for _, v in pairs(val) do
				if type(v) == "function" then
					count = count + 1
				end
			end
			if count > 0 then
				modules[#modules + 1] = { name = name, count = count }
			end
		end
	end
	table.sort(modules, function(a, b)
		return a.name < b.name
	end)
	return modules
end

return M
