---Picker interface — delegates to the configured backend.
---
---Each backend module must expose:
---  `open_functions_picker(results: submarine.FnResult[], module_name: string)`
---  `open_modules_picker(modules: submarine.ModuleEntry[], on_confirm: fun(name: string))`

---@class submarine.PickerBackend
---@field open_functions_picker fun(results: submarine.FnResult[], module_name: string): nil
---@field open_modules_picker fun(modules: submarine.ModuleEntry[], on_confirm: fun(module_name: string)): nil

local M = {}

---@type submarine.PickerBackend
local backend = require("submarine.pickers.snacks")

---Replace the active picker backend.
---@param b submarine.PickerBackend
function M.set_backend(b)
	backend = b
end

---@param results submarine.FnResult[]
---@param module_name string
function M.open_functions_picker(results, module_name)
	backend.open_functions_picker(results, module_name)
end

---@param modules submarine.ModuleEntry[]
---@param on_confirm fun(module_name: string): nil
function M.open_modules_picker(modules, on_confirm)
	backend.open_modules_picker(modules, on_confirm)
end

return M
