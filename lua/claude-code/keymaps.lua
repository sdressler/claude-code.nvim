---@mod claude-code.keymaps Keymap management for claude-code.nvim
---@brief [[
--- This module provides keymap registration and handling for claude-code.nvim.
--- It handles normal mode, terminal mode, and window navigation keymaps.
---@brief ]]

local M = {}

--- Send interrupt signal (Escape) to Claude terminal
function M.send_interrupt()
  require('claude-code.input').send_interrupt()
end

--- Register keymaps for claude-code.nvim
--- @param claude_code table The main plugin module
--- @param config table The plugin configuration
function M.register_keymaps(claude_code, config)
  local map_opts = { noremap = true, silent = true }

  -- Normal mode toggle keymaps
  if config.keymaps.toggle.normal then
    vim.api.nvim_set_keymap(
      'n',
      config.keymaps.toggle.normal,
      [[<cmd>ClaudeCode<CR>]],
      vim.tbl_extend('force', map_opts, { desc = 'Claude Code: Toggle' })
    )
  end

  if config.keymaps.toggle.terminal then
    -- Terminal mode toggle keymap
    -- In terminal mode, special keys like Ctrl need different handling
    -- We use a direct escape sequence approach for more reliable terminal mappings
    vim.api.nvim_set_keymap(
      't',
      config.keymaps.toggle.terminal,
      [[<C-\><C-n>:ClaudeCode<CR>]],
      vim.tbl_extend('force', map_opts, { desc = 'Claude Code: Toggle' })
    )
  end

  -- Interrupt Claude with Escape key
  vim.api.nvim_set_keymap(
    't',
    '<C-x>',
    [[<C-\><C-n>:lua require('claude-code.keymaps').send_interrupt()<CR>]],
    vim.tbl_extend('force', map_opts, { desc = 'Claude Code: Interrupt' })
  )

  -- Insert newline marker in terminal mode
  vim.api.nvim_set_keymap(
    't',
    '<S-CR>',
    [[\+Return]],
    vim.tbl_extend('force', map_opts, { desc = 'Claude Code: Insert newline marker' })
  )

  -- Register variant keymaps if configured
  if config.keymaps.toggle.variants then
    for variant_name, keymap in pairs(config.keymaps.toggle.variants) do
      if keymap then
        -- Convert variant name to PascalCase for command name (e.g., "continue" -> "Continue")
        local capitalized_name = variant_name:gsub('^%l', string.upper)
        local cmd_name = 'ClaudeCode' .. capitalized_name

        vim.api.nvim_set_keymap(
          'n',
          keymap,
          string.format([[<cmd>%s<CR>]], cmd_name),
          vim.tbl_extend('force', map_opts, { desc = 'Claude Code: ' .. capitalized_name })
        )
      end
    end
  end

  -- Register with which-key if it's available
  vim.defer_fn(function()
    local status_ok, which_key = pcall(require, 'which-key')
    if status_ok then
      if config.keymaps.toggle.normal then
        which_key.add {
          mode = 'n',
          { config.keymaps.toggle.normal, desc = 'Claude Code: Toggle', icon = '🤖' },
        }
      end
      if config.keymaps.toggle.terminal then
        which_key.add {
          mode = 't',
          { config.keymaps.toggle.terminal, desc = 'Claude Code: Toggle', icon = '🤖' },
        }
      end

      -- Register variant keymaps with which-key
      if config.keymaps.toggle.variants then
        for variant_name, keymap in pairs(config.keymaps.toggle.variants) do
          if keymap then
            local capitalized_name = variant_name:gsub('^%l', string.upper)
            which_key.add {
              mode = 'n',
              { keymap, desc = 'Claude Code: ' .. capitalized_name, icon = '🤖' },
            }
          end
        end
      end
    end
  end, 100)
end

--- Set up terminal-specific keymaps for window navigation
--- @param claude_code table The main plugin module
--- @param config table The plugin configuration
function M.setup_terminal_navigation(claude_code, config)
  -- Get current active Claude instance buffer
  local current_instance = claude_code.claude_code.current_instance
  local buf = current_instance and claude_code.claude_code.instances[current_instance]
  if buf and vim.api.nvim_buf_is_valid(buf) then
    -- All autocmds and keymaps disabled to prevent interference with Claude CLI UI
    -- The terminal is now in pure passthrough mode
    -- Users can use standard vim window navigation (Ctrl-\ Ctrl-n then Ctrl-w h/j/k/l)
  end
end

return M
