---@mod claude-code.input Input handling for claude-code.nvim
---@brief [[
--- This module handles user input in both terminal and buffer modes.
--- It provides the interface for sending messages to Claude via different
--- input methods.
---@brief ]]

local M = {}

--- Input buffer state
-- @table ClaudeCodeInputState
-- @field bufnr number|nil Current input buffer number
-- @field winid number|nil Current input window ID
-- @field instance_id string|nil Instance ID associated with this input
-- @field claude_code table|nil Reference to main plugin module
-- @field config table|nil Reference to plugin config
-- @field git table|nil Reference to git module
M.state = {
  bufnr = nil,
  winid = nil,
  instance_id = nil,
  claude_code = nil,
  config = nil,
  git = nil,
}

--- Input history storage per instance
-- @table ClaudeCodeHistory
M.history = {}

--- Add message to history
-- @param instance_id string Instance identifier
-- @param message string Message to add
function M.add_to_history(instance_id, message)
  if not M.history[instance_id] then
    M.history[instance_id] = { messages = {}, index = 0 }
  end
  table.insert(M.history[instance_id].messages, message)
  -- Reset index when new message is added
  M.history[instance_id].index = 0
end

--- Get previous message from history
-- @param instance_id string Instance identifier
-- @return string|nil Previous message or nil
function M.get_previous(instance_id)
  local hist = M.history[instance_id]
  if not hist or #hist.messages == 0 then
    return nil
  end
  if hist.index < #hist.messages then
    hist.index = hist.index + 1
    return hist.messages[#hist.messages - hist.index + 1]
  end
  return nil
end

--- Get next message from history
-- @param instance_id string Instance identifier
-- @return string|nil Next message or nil
function M.get_next(instance_id)
  local hist = M.history[instance_id]
  if not hist or hist.index <= 1 then
    return nil
  end
  hist.index = hist.index - 1
  if hist.index == 0 then
    return ''
  end
  return hist.messages[#hist.messages - hist.index + 1]
end

--- Insert files from fzf into the input buffer
function M.insert_files_from_fzf()
  local bufnr = M.state.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify('Input buffer is not valid', vim.log.levels.WARN)
    return
  end

  -- Use fzf-lua if available
  local fzf_lua_ok, fzf_lua = pcall(require, 'fzf-lua')
  if not fzf_lua_ok then
    vim.notify('fzf-lua not installed', vim.log.levels.WARN)
    return
  end

  -- Store cursor position and buffer before opening fzf
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]

  -- Open fzf files dialog with multi-select
  fzf_lua.files({
    multi_select = true,
    actions = {
      ['default'] = function(selected)
        if not selected or #selected == 0 then
          return
        end

        -- Format selected files
        local file_refs = {}
        for _, file in ipairs(selected) do
          -- Strip nerd font icons - remove everything before the first ASCII letter or dot
          local clean_path = file:gsub('^[^%w%.]+', '')

          -- Clean up any remaining whitespace
          clean_path = clean_path:gsub('^%s+', ''):gsub('%s+$', '')

          -- Normalize path to start with ./
          local normalized_path = clean_path
          if not normalized_path:match('^%.') then
            normalized_path = './' .. normalized_path
          end
          table.insert(file_refs, '`@' .. normalized_path .. '` ')
        end

        local file_string = table.concat(file_refs, ' ')

        -- Get current line
        local lines = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)
        local current_line = lines[1] or ''

        -- Insert file refs at cursor position
        local new_line = current_line:sub(1, col) .. file_string .. current_line:sub(col + 1)

        -- Save undo state to prevent . (repeat) from replicating file insertion
        vim.cmd('undojoin')
        vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })

        -- Find window with input buffer and focus it
        local win_ids = vim.fn.win_findbuf(bufnr)
        if #win_ids > 0 then
          vim.api.nvim_set_current_win(win_ids[1])
          -- Move cursor to end of inserted text
          vim.api.nvim_win_set_cursor(0, { row, col + #file_string })
        end
      end,
    },
  })
end

--- Insert directory from fzf into the input buffer
function M.insert_directory_from_fzf()
  local bufnr = M.state.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify('Input buffer is not valid', vim.log.levels.WARN)
    return
  end

  -- Use fzf-lua if available
  local fzf_lua_ok, fzf_lua = pcall(require, 'fzf-lua')
  if not fzf_lua_ok then
    vim.notify('fzf-lua not installed', vim.log.levels.WARN)
    return
  end

  -- Store cursor position and buffer before opening fzf
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]

  -- Open fzf directory selector (using git_branches as a workaround or live_grep with directory filtering)
  -- Most reliable: use find_files but filter for directories only
  vim.fn.system('find . -type d -not -path "*/.*" | head -100') -- Get directories for fzf

  fzf_lua.fzf_exec('find . -type d -not -path "*/.*"', {
    prompt = 'Select directory: ',
    previewer = false,
    actions = {
      ['default'] = function(selected)
        if not selected or #selected == 0 then
          return
        end

        -- Get first selection (directories are single-select)
        local dir = selected[1]

        -- Strip nerd font icons - remove everything before the first ASCII letter or dot
        local clean_path = dir:gsub('^[^%w%.]+', '')

        -- Clean up any remaining whitespace
        clean_path = clean_path:gsub('^%s+', ''):gsub('%s+$', '')

        -- Normalize path to start with ./
        local normalized_path = clean_path
        if not normalized_path:match('^%.') then
          normalized_path = './' .. normalized_path
        end

        local dir_ref = '`@' .. normalized_path .. '` '

        -- Get current line
        local lines = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)
        local current_line = lines[1] or ''

        -- Insert directory ref at cursor position
        local new_line = current_line:sub(1, col) .. dir_ref .. current_line:sub(col + 1)

        -- Save undo state
        vim.cmd('undojoin')
        vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })

        -- Find window with input buffer and focus it
        local win_ids = vim.fn.win_findbuf(bufnr)
        if #win_ids > 0 then
          vim.api.nvim_set_current_win(win_ids[1])
          -- Move cursor to end of inserted text
          vim.api.nvim_win_set_cursor(0, { row, col + #dir_ref })
        end
      end,
    },
  })
end

--- Send buffer content to Claude via the CLI terminal
function M.send_buffer_to_claude()
  local bufnr = M.state.bufnr
  local config = M.state.config
  local git = M.state.git
  local claude_code = M.state.claude_code

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify('Input buffer is not valid', vim.log.levels.WARN)
    return
  end

  -- Get buffer content - send everything in the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local message = table.concat(lines, '\n'):gsub('^%s+', ''):gsub('%s+$', '')

  if message:len() == 0 then
    vim.notify('Message is empty', vim.log.levels.WARN)
    return
  end

  -- Get the Claude terminal buffer
  local instance_id = M.state.instance_id or git.get_git_root() or vim.fn.getcwd()
  local claude_bufnr = claude_code.claude_code.instances[instance_id]

  if not claude_bufnr or not vim.api.nvim_buf_is_valid(claude_bufnr) then
    vim.notify('Claude terminal buffer not found', vim.log.levels.WARN)
    return
  end

  -- Focus the Claude terminal window first
  local claude_win_ids = vim.fn.win_findbuf(claude_bufnr)
  if #claude_win_ids == 0 then
    vim.notify('Claude terminal window not found', vim.log.levels.WARN)
    return
  end

  -- Switch to Claude terminal window
  vim.api.nvim_set_current_win(claude_win_ids[1])

  -- Get the job ID from the terminal buffer (now that we're focused on it)
  local job_id = nil
  pcall(function()
    job_id = vim.api.nvim_buf_get_var(claude_bufnr, 'terminal_job_id')
  end)

  if not job_id then
    vim.notify('Claude terminal job not found', vim.log.levels.WARN)
    return
  end

  -- Enter insert mode
  vim.cmd('startinsert')

  -- Send the message with newline
  vim.fn.chansend(job_id, message .. '\n')

  -- Simulate pressing Enter to execute the command in the terminal
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, true, true), 't', false)

  -- Add to history before clearing
  M.add_to_history(instance_id, message)

  -- Clear the input buffer after sending
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  vim.notify('Message sent to Claude', vim.log.levels.INFO)
end

--- Send interrupt signal (Escape) to Claude
function M.send_interrupt()
  local instance_id = M.state.instance_id
    or (M.state.git and M.state.git.get_git_root())
    or vim.fn.getcwd()
  local claude_code = M.state.claude_code

  if not claude_code then
    vim.notify('Claude Code instance not found', vim.log.levels.WARN)
    return
  end

  local claude_bufnr = claude_code.claude_code.instances[instance_id]
  if not claude_bufnr or not vim.api.nvim_buf_is_valid(claude_bufnr) then
    vim.notify('Claude terminal buffer not found', vim.log.levels.WARN)
    return
  end

  local job_id = nil
  pcall(function()
    job_id = vim.api.nvim_buf_get_var(claude_bufnr, 'terminal_job_id')
  end)

  if not job_id then
    vim.notify('Claude terminal job not found', vim.log.levels.WARN)
    return
  end

  vim.fn.chansend(job_id, '\27')
  vim.notify('Interrupt signal sent to Claude', vim.log.levels.INFO)
end

--- Navigate to previous message in history
function M.history_previous()
  local bufnr = M.state.bufnr
  local instance_id = M.state.instance_id
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) or not instance_id then
    return
  end
  local message = M.get_previous(instance_id)
  if message then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(message, '\n'))
  end
end

--- Navigate to next message in history
function M.history_next()
  local bufnr = M.state.bufnr
  local instance_id = M.state.instance_id
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) or not instance_id then
    return
  end
  local message = M.get_next(instance_id)
  if message then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(message, '\n'))
  end
end

--- Open history picker
function M.open_history_picker()
  local instance_id = M.state.instance_id
  if not instance_id or not M.history[instance_id] or #M.history[instance_id].messages == 0 then
    vim.notify('No history available', vim.log.levels.WARN)
    return
  end

  local hist = M.history[instance_id]
  local items = {}
  local seen = {}

  -- Create display items with message preview, eliminating duplicates
  for i, msg in ipairs(hist.messages) do
    if not seen[msg] then
      seen[msg] = true
      local preview = msg:sub(1, 60):gsub('\n', ' ')
      if #msg > 60 then
        preview = preview .. '...'
      end
      table.insert(items, { index = i, text = preview, full = msg })
    end
  end

  -- Reverse to show most recent first
  local reversed = {}
  for i = #items, 1, -1 do
    table.insert(reversed, items[i])
  end

  -- Use vim.ui.select for simple picker
  vim.ui.select(reversed, {
    prompt = 'Select from history: ',
    format_item = function(item)
      return item.text
    end,
  }, function(choice)
    if choice then
      local bufnr = M.state.bufnr
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(choice.full, '\n'))
        -- Move cursor to end - get window ID dynamically
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local win_ids = vim.fn.win_findbuf(bufnr)
        if #win_ids > 0 then
          vim.api.nvim_win_set_cursor(win_ids[1], { #lines, 0 })
        end
      end
    end
  end)
end

--- Create an input buffer for composing messages
--- @param config table Plugin configuration
--- @param git table Git module
--- @param instance_id string Instance identifier
--- @return number Buffer number
function M.create_input_buffer(config, git, instance_id)
  -- Generate unique buffer name based on instance ID, sanitizing path separators
  local id = instance_id or 'default'
  -- Replace path separators with underscores to avoid swap file conflicts
  local sanitized_id = id:gsub('[/\\]', '_')
  local buf_name = 'claude-code-input-' .. sanitized_id

  -- Check if buffer with this name already exists
  local existing_buf = vim.fn.bufnr(buf_name)
  if existing_buf ~= -1 and vim.api.nvim_buf_is_valid(existing_buf) then
    -- Reuse existing buffer
    vim.api.nvim_buf_set_lines(existing_buf, 0, -1, false, {})
    vim.api.nvim_set_option_value('swapfile', false, { buf = existing_buf })
    M.state.bufnr = existing_buf
    M.state.instance_id = instance_id
    return existing_buf
  end

  -- Create a new buffer with unique name
  local bufnr = vim.api.nvim_create_buf(false, false) -- unlisted, not scratch

  -- Set buffer options BEFORE setting name to prevent swap file creation
  -- bufhidden=hide ensures buffer won't be written, swapfile=false prevents swap files
  vim.api.nvim_set_option_value('swapfile', false, { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = bufnr })
  vim.api.nvim_set_option_value('buflisted', true, { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', config.input.buffer.filetype, { buf = bufnr })

  vim.api.nvim_buf_set_name(bufnr, buf_name)

  -- Start with empty buffer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  -- Enable copilot if configured (for zbirenbaum/copilot.lua)
  if config.input.buffer.enable_copilot then
    pcall(function()
      -- Enable copilot.lua for this buffer
      vim.b[bufnr].copilot_enabled = true
      -- Also try to attach copilot if the plugin is loaded
      local copilot_ok, copilot = pcall(require, 'copilot.api')
      if copilot_ok and copilot.get_client then
        copilot.get_client()
      end
    end)
  end

  -- Store state
  M.state.bufnr = bufnr
  M.state.instance_id = instance_id

  return bufnr
end

--- Open Claude terminal and input buffer side-by-side
--- @param claude_code table The main plugin module
--- @param config table Plugin configuration
--- @param git table Git module
--- @param instance_id string Instance identifier
function M.open_input_buffer(claude_code, config, git, instance_id)
  local terminal = require('claude-code.terminal')

  -- First, ensure Claude terminal is open
  terminal.toggle(claude_code, config, git)

  local bufnr = M.create_input_buffer(config, git, instance_id)

  -- Get current window (should be the Claude terminal after toggle)
  local claude_win = vim.api.nvim_get_current_win()

  -- Create a horizontal split below for input
  vim.cmd('below split')

  -- Switch to the new split and set our input buffer
  vim.api.nvim_win_set_buf(0, bufnr)

  -- Resize the input split (use half of remaining space or smaller)
  local total_height = vim.o.lines - vim.o.cmdheight - 1
  local input_height = math.floor(total_height * 0.3)
  vim.cmd('resize ' .. input_height)

  -- Capture current window ID
  local input_win = vim.api.nvim_get_current_win()

  -- Set buffer options (already set in create_input_buffer)
  vim.api.nvim_set_option_value('number', true, { win = input_win })
  vim.api.nvim_set_option_value('wrap', true, { win = input_win })
  vim.api.nvim_set_option_value('linebreak', true, { win = input_win })

  M.state.winid = input_win
  M.state.claude_code = claude_code
  M.state.config = config
  M.state.git = git

  -- Set up keymaps
  M.setup_buffer_keymaps(bufnr, config, git)
end

--- Set up buffer keymaps for input mode
--- @param bufnr number Buffer number
--- @param config table Plugin configuration
--- @param git table Git module
--- @private
function M.setup_buffer_keymaps(bufnr, config, git)
  -- Capture keymaps in closure so they persist after state is cleared
  local send_key = config.input.buffer.keymaps.send
  local insert_files_key = config.input.buffer.keymaps.insert_files
  local insert_directory_key = config.input.buffer.keymaps.insert_directory
  local cancel_key = config.input.buffer.keymaps.cancel

  local opts = { buffer = bufnr, noremap = true, silent = true }

  vim.keymap.set('i', send_key, M.send_buffer_to_claude, opts)
  vim.keymap.set('n', send_key, M.send_buffer_to_claude, opts)

  -- Insert files keymap
  vim.keymap.set('i', insert_files_key, M.insert_files_from_fzf, opts)
  vim.keymap.set('n', insert_files_key, M.insert_files_from_fzf, opts)

  -- Insert directory keymap
  vim.keymap.set('i', insert_directory_key, M.insert_directory_from_fzf, opts)
  vim.keymap.set('n', insert_directory_key, M.insert_directory_from_fzf, opts)

  -- Cancel keymap
  vim.keymap.set('n', cancel_key, function()
    -- Close the window
    if M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then
      vim.api.nvim_win_close(M.state.winid, true)
    end
    M.state.winid = nil
  end, opts)

  -- History navigation keymaps
  vim.keymap.set('i', '<C-p>', M.history_previous, opts)
  vim.keymap.set('i', '<C-n>', M.history_next, opts)
  vim.keymap.set('n', '<C-p>', M.history_previous, opts)
  vim.keymap.set('n', '<C-n>', M.history_next, opts)

  -- History picker keymap
  vim.keymap.set('i', '<C-h>', M.open_history_picker, opts)
  vim.keymap.set('n', '<C-h>', M.open_history_picker, opts)

  -- Interrupt Claude
  vim.keymap.set('i', '<C-x>', M.send_interrupt, opts)
  vim.keymap.set('n', '<C-x>', M.send_interrupt, opts)

  vim.keymap.set('i', '<Esc>', '<Esc>', opts) -- Allow escape to exit insert mode

  -- Set up autocommand to enter insert mode when buffer is entered
  vim.api.nvim_create_autocmd('BufEnter', {
    group = vim.api.nvim_create_augroup('ClaudeCodeInputKeymaps_' .. bufnr, { clear = true }),
    buffer = bufnr,
    callback = function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.cmd('startinsert')
      end
    end,
  })
end

return M
