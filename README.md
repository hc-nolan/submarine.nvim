- Opens a Snacks picker that lets you search through module function exports
- `Snacks.picker.commands()` accomplishes the module part (if the plugin registers a command), but it doesn't show function exports
  - However, they're available, because you can tab-complete through them
- Bonus
  - Support for plugins that don't register commands with `vim.api.nvim_create_user_command`
  - Load plugin docstrings and/or definitions
    - Look at how `vim.lsp.buf.hover()` works.
```lua
-- this returns the docstring and stuff for what's under the cursor
-- one liner:
-- :lua local c=vim.lsp.get_clients({name='lua_ls'})[1]; local pos={line=vim.fn.line('.')-1, character=vim.fn.col('.')-1}; c:request('textDocument/completion',{textDocument={uri=vim.uri_from_bufnr(0)},position=pos},function(e,r) local items=r and (r.items or r) or {}; if items[1] then c:request('completionItem/resolve',items[1],function(e2,r2) print(vim.inspect(r2 and r2.documentation)) end) end end)
local c = vim.lsp.get_clients({name='lua_ls'})[1]
local pos = {line=vim.fn.line('.')-1, character=vim.fn.col('.')-1}
c:request(
  'textDocument/completion',
  {textDocument={uri=vim.uri_from_bufnr(0)},position=pos},
  function(e,r)
    local items=r and (r.items or r) or {}
    if items[1] then c:request(
      'completionItem/resolve',
      items[1],
      function(e2,r2)
        print(vim.inspect(r2 and r2.documentation))
      end)
    end
  end)`
```
- So how do I make this work with a function name instead of cursor position?

# Initial thoughts

- The plugin that gave me the idea was Gitsigns so that's what I'm going to work with first.
- This prints the exports: `:lua print(vim.inspect(require('gitsigns.cli').complete('', 'Gitsigns ')))`
  - `{ "attach", "undo_stage_hunk", "refresh", "stage_buffer", "reset_buffer_index", "setloclist", "setqflist", "next_hunk", "detach_all", "preview_hunk", "preview_hunk_inline", "select_hunk", "get_hunks", "toggle_numhl", "toggle_linehl", "toggle_word_diff", "toggle_current_line_blame", "toggle_deleted", "detach", "stage_hunk", "reset_base", "show_commit", "get_actions", "reset_hunk", "show", "blame_line", "toggle_signs", "reset_buffer", "prev_hunk", "nav_hunk", "blame", "change_base", "diffthis", "detach", "attach", "detach_all", "dump_cache", "debug_messages", "clear_debug" }`



- Need to look at
    - LSP specification
    - LuaLS code
    - Does LSP/LuaLS have a way to arbitrarily query modules and functions? Everything seems to be based on what's in the current cursor buffer.

https://neovim.io/doc/user/lsp/
https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
https://github.com/Microsoft/language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md
https://github.com/LuaLS/lua-language-server
