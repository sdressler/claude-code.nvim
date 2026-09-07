---@mod claude-code Claude Code Neovim Integration
---@brief [[
--- A plugin for seamless integration between Claude Code AI assistant and Neovim.
--- This plugin provides a terminal-based interface to Claude Code within Neovim.
---
--- Requirements:
--- - Neovim 0.7.0 or later
--- - Claude Code CLI tool installed and available in PATH
--- - plenary.nvim (dependency for git operations)
---
--- Usage:
--- ```lua
--- require('claude-code').setup({
---   -- Configuration options (optional)
--- })
--- ```
---@brief ]]

-- Import modules
local config = require('claude-code.config')
local commands = require('claude-code.commands')
local keymaps = require('claude-code.keymaps')
local file_refresh = require('claude-code.file_refresh')
local terminal = require('claude-code.terminal')
local input = require('claude-code.input')
local git = require('claude-code.git')
local version = require('claude-code.version')

local M = {}

-- Make imported modules available
M.commands = commands

-- Store the current configuration
--- @type table
M.config = {}

-- Terminal buffer and window management
--- @type table
M.claude_code = terminal.terminal

--- Force insert mode when entering the Claude Code window
--- This is a public function used in keymaps
function M.force_insert_mode()
  terminal.force_insert_mode(M, M.config)
end

--- Get the current active buffer number
--- @return number|nil bufnr Current Claude instance buffer number or nil
local function get_current_buffer_number()
  -- Get current instance from the instances table
  local current_instance = M.claude_code.current_instance
  if current_instance and type(M.claude_code.instances) == 'table' then
    return M.claude_code.instances[current_instance]
  end
  return nil
end

--- Toggle the Claude Code terminal window or open buffer input
--- This is a public function used by commands
function M.toggle()
  -- Check if we should use buffer input mode instead of terminal
  if M.config.input.mode == 'buffer' then
    local instance_id = terminal.get_instance_id(M.config, git)
    input.open_input_buffer(M, M.config, git, instance_id)
  else
    -- Use terminal mode (default behavior)
    terminal.toggle(M, M.config, git)

    -- Set up terminal navigation keymaps after toggling
    local bufnr = get_current_buffer_number()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      keymaps.setup_terminal_navigation(M, M.config)
    end
  end
end

--- Open a new tabpage and start (or reveal) its Claude Code instance
--- With `git.multi_instance = "tab"`, this always starts a fresh session.
function M.open_in_new_tab()
  vim.cmd('tabnew')
  M.toggle()
end

--- Toggle the Claude Code terminal window with a specific command variant
--- @param variant_name string The name of the command variant to use
function M.toggle_with_variant(variant_name)
  if not variant_name or not M.config.command_variants[variant_name] then
    -- If variant doesn't exist, fall back to regular toggle
    return M.toggle()
  end

  -- Variants only work in terminal mode
  if M.config.input.mode == 'buffer' then
    vim.notify(
      'Command variants are not supported in buffer input mode. '
        .. 'Switch to terminal mode or use the buffer directly.',
      vim.log.levels.WARN
    )
    return M.toggle()
  end

  -- Store the original command
  local original_command = M.config.command

  -- Set the command with the variant args
  M.config.command = original_command .. ' ' .. M.config.command_variants[variant_name]

  -- Call the toggle function with the modified command
  terminal.toggle(M, M.config, git)

  -- Set up terminal navigation keymaps after toggling
  local bufnr = get_current_buffer_number()
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    keymaps.setup_terminal_navigation(M, M.config)
  end

  -- Restore the original command
  M.config.command = original_command
end

--- Toggle the terminal for an additional configured tool (e.g. Devin)
--- @param tool_name string Name of the tool, matching a key in config.tools
--- @param variant_name string|nil Optional command variant for that tool
function M.toggle_tool(tool_name, variant_name)
  local tool_config = M.config.tools[tool_name]
  if not tool_config then
    vim.notify('Claude Code: unknown tool "' .. tool_name .. '"', vim.log.levels.ERROR)
    return
  end

  local command = tool_config.command
  if variant_name then
    local variant_args = tool_config.command_variants and tool_config.command_variants[variant_name]
    if variant_args then
      command = command .. ' ' .. variant_args
    end
  end

  terminal.toggle(M, M.config, git, { name = tool_name, command = command })

  -- Set up terminal navigation keymaps after toggling
  local bufnr = get_current_buffer_number()
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    keymaps.setup_terminal_navigation(M, M.config)
  end
end

--- Get the current version of the plugin
--- @return string version Current version string
function M.get_version()
  return version.string()
end

--- Version information
M.version = version

--- Setup function for the plugin
--- @param user_config? table User configuration table (optional)
function M.setup(user_config)
  -- Parse and validate configuration
  -- Don't use silent mode for regular usage - users should see config errors
  M.config = config.parse_config(user_config, false)

  -- Set up autoread option
  vim.o.autoread = true

  -- Set up file refresh functionality
  file_refresh.setup(M, M.config)

  -- Register commands
  commands.register_commands(M)

  -- Register keymaps
  keymaps.register_keymaps(M, M.config)
end

return M
