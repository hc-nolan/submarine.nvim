local config = require("submarine.config")

local M = {}

---@alias submarine.LualsCallback fun(client_id: integer|nil): nil

local luals_ready = false
local our_client_id = nil ---@type integer|nil
local workspace_token = nil ---@type string|integer|nil
local pending_callbacks = {} ---@type submarine.LualsCallback[]

local PROGRESS_ID = "submarine_workspace_progress"

---@return vim.lsp.Client|nil
local function find_existing_client()
	for _, c in ipairs(vim.lsp.get_clients({ name = "lua_ls" })) do
		if c.config.root_dir == config.root_dir then
			return c
		end
	end
end

---Start or reuse the lua_ls client. `callback` is called once the client is
---initialized *and* has finished loading its workspace. If the workspace is
---still loading, queues the callback to fire automatically when ready.
---@param callback submarine.LualsCallback
function M.get_luals(callback)
	-- Reuse a client we already own.
	if our_client_id then
		if luals_ready then
			callback(our_client_id)
		else
			table.insert(pending_callbacks, callback)
		end
		return
	end

	-- Reuse a client started externally (e.g. user's own lspconfig).
	local existing = find_existing_client()
	if existing then
		callback(existing.id)
		return
	end

	-- No client — start one and take ownership.
	local id = vim.lsp.start({
		name = "lua_ls",
		cmd = config.luals_cmd,
		root_dir = config.root_dir,
		settings = {
			Lua = {
				workspace = {
					library = { vim.env.VIMRUNTIME },
					checkThirdParty = false,
				},
			},
		},
		handlers = {
			["$/progress"] = function(_, result, ctx)
				local v = result.value
				if v and v.kind == "begin" and v.title == "Loading workspace" then
					workspace_token = result.token
					luals_ready = false
					vim.notify("submarine: indexing workspace…", vim.log.levels.INFO, {
						id = PROGRESS_ID,
						timeout = false,
					})
				elseif v and v.kind == "report" and result.token == workspace_token then
					vim.notify("submarine: indexing workspace — " .. (v.message or ""), vim.log.levels.INFO, {
						id = PROGRESS_ID,
						timeout = false,
					})
				elseif v and v.kind == "end" and result.token == workspace_token then
					workspace_token = nil
					luals_ready = true
					if _G.Snacks and _G.Snacks.notifier then
						Snacks.notifier.hide(PROGRESS_ID)
					end
					local cbs = pending_callbacks
					pending_callbacks = {}
					for _, cb in ipairs(cbs) do
						cb(ctx.client_id)
					end
				end
			end,
		},
	})
	if not id then
		callback(nil)
		return
	end
	our_client_id = id
	-- Detach from the current buffer immediately: submarine only needs the
	-- client for request/response, never for buffer-level features.
	pcall(vim.lsp.buf_detach_client, vim.api.nvim_get_current_buf(), id)
	if luals_ready then
		callback(id)
	else
		table.insert(pending_callbacks, callback)
	end
end

---Stop the lua_ls client if submarine started it. No-op if the client was
---already running before submarine attached.
---@param client_id integer
function M.stop_luals(client_id)
	if our_client_id ~= client_id then
		return
	end
	our_client_id = nil
	luals_ready = false
	pending_callbacks = {}
	local client = vim.lsp.get_client_by_id(client_id)
	if client then
		client:stop(true)
	end
end

---@alias submarine.DocsCallback fun(results: submarine.FnResult[]): nil

---Fetch hover documentation for each entry in `fns` via lua_ls, then call
---`callback` with the completed results list.
---@param fns submarine.FnEntry[]
---@param client_id integer
---@param module_name string
---@param callback submarine.DocsCallback
function M.fetch_docs(fns, client_id, module_name, callback)
	local client = vim.lsp.get_client_by_id(client_id)
	if not client then
		vim.notify("submarine: lua_ls client lost before fetching docs", vim.log.levels.ERROR)
		return
	end

	local opened_uris = {} ---@type table<string, boolean>

	-- Separate Lua-defined and C-defined functions.
	local lua_fns, c_fns = {}, {} ---@type submarine.FnEntry[], submarine.FnEntry[]
	for _, entry in ipairs(fns) do
		if entry.info.source:sub(1, 1) == "@" then
			lua_fns[#lua_fns + 1] = entry
		else
			c_fns[#c_fns + 1] = entry
		end
	end

	-- Open each unique Lua source file so lua_ls can analyze it on demand.
	for _, entry in ipairs(lua_fns) do
		local uri = vim.uri_from_fname(entry.info.source:sub(2))
		if not opened_uris[uri] then
			opened_uris[uri] = true
			local ok, lines = pcall(vim.fn.readfile, entry.info.source:sub(2))
			if ok then
				client:notify("textDocument/didOpen", {
					textDocument = { uri = uri, languageId = "lua", version = 0, text = table.concat(lines, "\n") },
				})
			end
		end
	end

	-- For C functions, build a virtual document of field-access expressions so
	-- lua_ls resolves them from its built-in stdlib definitions.
	local c_virtual_uri = vim.uri_from_fname("/tmp/submarine_hover.lua")
	local req_prefix = string.format('require("%s").', module_name)
	if #c_fns > 0 then
		local virtual_lines = {}
		for i, entry in ipairs(c_fns) do
			table.sort(entry.names)
			virtual_lines[i] = req_prefix .. entry.names[1]
		end
		opened_uris[c_virtual_uri] = true
		client:notify("textDocument/didOpen", {
			textDocument = {
				uri = c_virtual_uri,
				languageId = "lua",
				version = 0,
				text = table.concat(virtual_lines, "\n"),
			},
		})
	end

	---@type submarine.FnResult[]
	local results = {}
	local pending = #fns

	local function finish()
		for uri in pairs(opened_uris) do
			client:notify("textDocument/didClose", { textDocument = { uri = uri } })
		end
		callback(results)
	end

	for _, entry in ipairs(lua_fns) do
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
					finish()
				end
			end
		)
	end

	for i, entry in ipairs(c_fns) do
		local display_name = table.concat(entry.names, " / ")
		client:request(
			"textDocument/hover",
			{ textDocument = { uri = c_virtual_uri }, position = { line = i - 1, character = #req_prefix } },
			function(err, result)
				local docs ---@type string|nil
				if not err and result and result.contents then
					local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
					local value = table.concat(lines, "\n")
					if value ~= "" then
						docs = value
					end
				end
				if not docs then
					docs = string.format("*No documentation available.*\n\n`%s`", display_name)
				end
				results[#results + 1] = { name = display_name, docs = docs }
				pending = pending - 1
				if pending == 0 then
					finish()
				end
			end
		)
	end
end

return M
