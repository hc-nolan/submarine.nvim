local config = require("submarine.config")

local M = {}

---@alias submarine.LualsCallback fun(client_id: integer|nil): nil

local luals_ready = false
local workspace_token = nil ---@type string|integer|nil
local workspace_progress = nil ---@type string|nil

---Start or reuse the lua_ls client. `callback` is called once the client is
---initialized *and* has finished loading its workspace. If the workspace is
---still loading, notifies the user and returns without calling `callback`.
---@param callback submarine.LualsCallback
function M.get_luals(callback)
	local id = vim.lsp.start({
		name = "lua_ls",
		cmd = config.luals_cmd,
		root_dir = config.root_dir,
		settings = {
			Lua = {
				workspace = {
					library = vim.api.nvim_get_runtime_file("", true),
					checkThirdParty = false,
				},
			},
		},
		handlers = {
			["$/progress"] = function(_, result, ctx)
				local v = result.value
				if v and v.kind == "begin" and v.title == "Loading workspace" then
					workspace_token = result.token
					workspace_progress = v.message
					luals_ready = false
				elseif v and v.kind == "report" and result.token == workspace_token then
					workspace_progress = v.message
				elseif v and v.kind == "end" and result.token == workspace_token then
					workspace_token = nil
					workspace_progress = nil
					luals_ready = true
				end
			end,
		},
	})
	if not id then
		callback(nil)
		return
	end
	if luals_ready then
		callback(id)
	else
		local msg = "submarine: lua_ls is still loading workspace"
		if workspace_progress then
			msg = msg .. " (" .. workspace_progress .. ")"
		end
		vim.notify(msg .. " — try again in a moment", vim.log.levels.WARN)
	end
end

---@alias submarine.DocsCallback fun(results: submarine.FnResult[]): nil

---Fetch hover documentation for each entry in `fns` via lua_ls, then call
---`callback` with the completed results list.
---@param fns submarine.FnEntry[]
---@param client_id integer
---@param callback submarine.DocsCallback
function M.fetch_docs(fns, client_id, callback)
	local client = vim.lsp.get_client_by_id(client_id)
	if not client then
		vim.notify("submarine: lua_ls client lost before fetching docs", vim.log.levels.ERROR)
		return
	end

	---@type submarine.FnResult[]
	local results = {}
	local pending = #fns

	for _, entry in ipairs(fns) do
		local info = entry.info
		local src_path = info.source:sub(2)
		local uri = vim.uri_from_fname(src_path)
		table.sort(entry.names)
		local display_name = table.concat(entry.names, " / ")

		client:request(
			"textDocument/hover",
			{ textDocument = { uri = uri }, position = { line = info.linedefined - 1, character = 0 } },
			function(err, result)
				local docs ---@type string|nil
				if not err and result and result.contents then
					local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
					local value = table.concat(lines, "\n")
					if value ~= "" and value:find("function", 1, true) then
						docs = value
					end
				end
				if not docs then
					docs = string.format("*No documentation available.*\n\n`%s:%d`", src_path, info.linedefined)
				end
				results[#results + 1] = { name = display_name, docs = docs }
				pending = pending - 1
				if pending == 0 then
					callback(results)
				end
			end
		)
	end
end

return M
