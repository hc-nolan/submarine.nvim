# submarine.nvim

Browse loaded Lua modules and their exported functions, with hover documentation
sourced from lua-language-server.

## Requirements

- Neovim ≥ 0.10
- [lua-language-server](https://github.com/LuaLS/lua-language-server) on `$PATH`
- [snacks.nvim](https://github.com/folke/snacks.nvim) (picker backend)

## Installation

Add to your `init.lua`:

```lua
vim.pack.add({
  { src = "https://github.com/hc-nolan/submarine.nvim" },
  { src = "https://github.com/folke/snacks.nvim" }
})
```

## Usage

```lua
-- Browse all loaded top-level modules, then drill into a module's functions
require("submarine").pick()

-- Jump straight to a specific module's functions
require("submarine").pick_functions("snacks")
```

## Configuration

```lua
require("submarine").setup({
  -- Command used to start lua-language-server
  luals_cmd = { "lua-language-server" },

  -- Workspace root passed to lua_ls (controls which files it indexes)
  root_dir = vim.fn.stdpath("config"),
})
```

## Adding a picker backend

Adding support for a different picker (telescope, fzf-lua, etc.) is pretty
straightforward. Create a module that exposes two functions matching the
`submarine.PickerBackend` interface in `lua/submarine/pickers/init.lua`, then
swap it in at startup:

```lua
require("submarine.pickers").set_backend(require("submarine.pickers.my_picker"))
```

## Notes

- Only modules already present in `package.loaded` are shown; submarine never
  `require`s anything on your behalf.
- Submodule names (those containing a `.`) are excluded from `pick()`; call
  `pick_functions("my.submodule")` directly if needed.
- Functions defined in C or via `load()` / `loadstring()` are silently skipped,
  as they have no source file for lua-language-server to index.
- Aliased functions (multiple keys pointing to the same function) are grouped
  into a single entry displayed as `foo / bar`.
