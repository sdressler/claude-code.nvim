---@mod claude-code.file_refresh File refresh functionality for claude-code.nvim
---@brief [[
--- This module provides file refresh functionality to detect and reload files
--- that have been modified by Claude Code or other external processes.
---@brief ]]

local M = {}

--- Timer for checking file changes
--- @type userdata|nil
local refresh_timer = nil

--- Setup autocommands for file change detection
--- @param claude_code table The main plugin module
--- @param config table The plugin configuration
function M.setup(claude_code, config)
  if not config.refresh.enable then
    return
  end

  local augroup = vim.api.nvim_create_augroup('ClaudeCodeFileRefresh', { clear = true })

  -- Check for file changes only on focus gain (not during normal buffer navigation)
  vim.api.nvim_create_autocmd('FocusGained', {
    group = augroup,
    pattern = '*',
    callback = function()
      -- Skip checktime for Claude terminal buffers
      local is_claude_terminal = pcall(vim.api.nvim_buf_get_var, 0, 'claude_terminal')
      if not is_claude_terminal and vim.fn.filereadable(vim.fn.expand '%') == 1 then
        vim.cmd 'checktime'
      end
    end,
    desc = 'Check for file changes on disk',
  })

  -- Clean up any existing timer
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end

  -- Timer disabled to prevent flickering - FocusGained handles file changes

  -- Create an autocommand that notifies when a file has been changed externally
  if config.refresh.show_notifications then
    vim.api.nvim_create_autocmd('FileChangedShellPost', {
      group = augroup,
      pattern = '*',
      callback = function()
        vim.notify('File changed on disk. Buffer reloaded.', vim.log.levels.INFO)
      end,
      desc = 'Notify when a file is changed externally',
    })
  end

  -- Set a shorter updatetime while Claude Code is open
  claude_code.claude_code.saved_updatetime = vim.o.updatetime

  -- Disabled updatetime modification to prevent interference with Claude CLI's UI updates
end

--- Clean up the file refresh functionality (stop the timer)
function M.cleanup()
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end
end

return M
