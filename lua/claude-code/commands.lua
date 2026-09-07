---@mod claude-code.commands Command registration for claude-code.nvim
---@brief [[
--- This module provides command registration and handling for claude-code.nvim.
--- It defines user commands and command handlers.
---@brief ]]

local input = require('claude-code.input')

local M = {}

--- @type table<string, function> List of available commands and their handlers
M.commands = {}

--- Register commands for the claude-code plugin
--- @param claude_code table The main plugin module
function M.register_commands(claude_code)
  -- Create the user command for toggling Claude Code
  vim.api.nvim_create_user_command('ClaudeCode', function()
    claude_code.toggle()
  end, { desc = 'Toggle Claude Code terminal' })

  -- Create commands for each command variant
  for variant_name, variant_args in pairs(claude_code.config.command_variants) do
    if variant_args ~= false then
      -- Convert variant name to PascalCase for command name (e.g., "continue" -> "Continue")
      local capitalized_name = variant_name:gsub('^%l', string.upper)
      local cmd_name = 'ClaudeCode' .. capitalized_name

      vim.api.nvim_create_user_command(cmd_name, function()
        claude_code.toggle_with_variant(variant_name)
      end, { desc = 'Toggle Claude Code terminal with ' .. variant_name .. ' option' })
    end
  end

  -- Open Claude Code in a new tabpage (new session when multi_instance = "tab")
  vim.api.nvim_create_user_command('ClaudeCodeTab', function()
    claude_code.open_in_new_tab()
  end, { desc = 'Open Claude Code terminal in a new tab' })

  -- Add version command
  vim.api.nvim_create_user_command('ClaudeCodeVersion', function()
    vim.notify('Claude Code version: ' .. claude_code.version(), vim.log.levels.INFO)
  end, { desc = 'Display Claude Code version' })

  -- Add send command for buffer input mode
  vim.api.nvim_create_user_command('ClaudeCodeSend', function()
    input.send_buffer_to_claude()
  end, { desc = 'Send buffer content to Claude (buffer input mode)' })

  -- Register commands for each additional configured tool (e.g. Devin)
  local tools = (claude_code.config and claude_code.config.tools) or {}
  for tool_name, tool_config in pairs(tools) do
    -- Convert tool name to PascalCase for command name (e.g., "devin" -> "Devin")
    local tool_capitalized = tool_name:gsub('^%l', string.upper)
    local tool_cmd_name = tool_capitalized .. 'Code'

    vim.api.nvim_create_user_command(tool_cmd_name, function()
      claude_code.toggle_tool(tool_name)
    end, { desc = 'Toggle ' .. tool_capitalized .. ' terminal' })

    for variant_name, variant_args in pairs(tool_config.command_variants or {}) do
      if variant_args ~= false then
        local variant_capitalized = variant_name:gsub('^%l', string.upper)
        local variant_cmd_name = tool_cmd_name .. variant_capitalized

        vim.api.nvim_create_user_command(
          variant_cmd_name,
          function()
            claude_code.toggle_tool(tool_name, variant_name)
          end,
          { desc = 'Toggle ' .. tool_capitalized .. ' terminal with ' .. variant_name .. ' option' }
        )
      end
    end
  end
end

return M
