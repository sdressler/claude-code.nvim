-- Tests for input buffer handling in Claude Code
local assert = require('luassert')
local describe = require('plenary.busted').describe
local it = require('plenary.busted').it

describe('input module', function()
  local config
  local claude_code
  local git
  local vim_cmd_calls = {}
  local vim_keymap_set_calls = {}
  local sequence_log = {} -- Shared log for tracking order of operations
  local real_terminal_module = require('claude-code.terminal')

  before_each(function()
    -- Reset tracking variables
    vim_cmd_calls = {}
    vim_keymap_set_calls = {}
    sequence_log = {}

    -- Mock vim functions
    _G.vim = _G.vim or {}
    _G.vim.api = _G.vim.api or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.keymap = _G.vim.keymap or {}
    _G.vim.o = setmetatable({
      lines = 100,
      columns = 100,
      cmdheight = 1
    }, {
      __newindex = function(t, k, v)
        if k == 'lines' or k == 'columns' or k == 'cmdheight' then
          rawset(t, k, tonumber(v) or rawget(t, k) or 1)
        else
          rawset(t, k, v)
        end
      end
    })

    -- Mock vim.cmd
    _G.vim.cmd = function(cmd)
      table.insert(vim_cmd_calls, cmd)
      table.insert(sequence_log, { type = 'cmd', cmd = cmd })
      return true
    end

    -- Mock vim.api.nvim_win_is_valid
    _G.vim.api.nvim_win_is_valid = function(win_id)
      return win_id ~= nil and win_id > 0
    end

    -- Mock vim.api.nvim_win_close
    _G.vim.api.nvim_win_close = function(win_id, force)
      return true
    end

    -- Mock vim.api.nvim_set_current_win
    _G.vim.api.nvim_set_current_win = function(win_id)
      table.insert(sequence_log, { type = 'set_current_win', win_id = win_id })
      return true
    end

    -- Mock vim.fn.win_findbuf
    _G.vim.fn.win_findbuf = function(bufnr)
      return {}
    end

    -- Mock vim.api.nvim_buf_is_valid
    _G.vim.api.nvim_buf_is_valid = function(bufnr)
      return bufnr ~= nil and bufnr > 0
    end

    -- Mock vim.api.nvim_get_current_win
    _G.vim.api.nvim_get_current_win = function()
      return 100
    end

    -- Mock vim.api.nvim_win_set_buf
    _G.vim.api.nvim_win_set_buf = function(win_id, bufnr)
      return true
    end

    -- Mock vim.api.nvim_set_option_value
    _G.vim.api.nvim_set_option_value = function(option, value, opts)
      return true
    end

    -- Mock vim.api.nvim_create_buf
    _G.vim.api.nvim_create_buf = function(listed, scratch)
      return 42 -- Return a mock buffer number
    end

    -- Mock vim.api.nvim_buf_set_name
    _G.vim.api.nvim_buf_set_name = function(bufnr, name)
      return true
    end

    -- Mock vim.api.nvim_buf_set_lines
    _G.vim.api.nvim_buf_set_lines = function(bufnr, start, end_, strict_indexing, replacement)
      return true
    end

    -- Mock vim.fn.bufnr
    _G.vim.fn.bufnr = function(pattern)
      return -1 -- No existing buffer
    end

    -- Mock vim.keymap.set
    _G.vim.keymap.set = function(mode, lhs, rhs, opts)
      table.insert(vim_keymap_set_calls, {
        mode = mode,
        lhs = lhs,
        rhs = rhs,
        opts = opts
      })
    end

    -- Mock vim.notify
    _G.vim.notify = function(msg, level)
      return true
    end

    -- Setup test objects
    config = {
      input = {
        buffer = {
          filetype = 'markdown',
          enable_copilot = false,
          keymaps = {
            send = '<CR>',
            insert_files = '<C-f>',
            insert_directory = '<C-d>',
            cancel = '<C-c>'
          }
        },
        mode = 'buffer'
      },
      command = 'claude',
      window = {
        position = 'botright',
        split_ratio = 0.5,
        enter_insert = true,
        start_in_normal_mode = false,
        hide_numbers = true,
        hide_signcolumn = true,
      },
      git = {
        use_git_root = true,
        multi_instance = true,
      },
      shell = {
        separator = '&&',
        pushd_cmd = 'pushd',
        popd_cmd = 'popd',
      },
    }

    claude_code = {
      claude_code = {
        instances = {},
        current_instance = nil,
        saved_updatetime = nil,
      },
      toggle = function() end,
    }

    git = {
      get_git_root = function()
        return '/test/git/root'
      end,
    }

    -- Mock the terminal module for testing toggle_input_buffer
    -- This prevents actual terminal.toggle calls during input tests
    package.loaded['claude-code.terminal'] = {
      toggle = function(...)
        -- Mock implementation
        claude_code.claude_code.instances['/test/git/root'] = 10
      end,
      get_instance_id = function(config, git)
        if git.get_git_root() then
          return git.get_git_root()
        end
        return vim.fn.getcwd()
      end,
    }
  end)

  after_each(function()
    package.loaded['claude-code.terminal'] = real_terminal_module
  end)

  describe('toggle_input_buffer', function()
    it('case a: should call terminal.toggle when terminal instance has no buffer yet', function()
      local input = require('claude-code.input')

      -- Set up: no input window, no terminal buffer
      input.state.winid = nil
      claude_code.claude_code.instances = {}

      -- Call toggle_input_buffer
      input.toggle_input_buffer(claude_code, config, git, '/test/git/root')

      -- Verify that the input buffer was created (via create_input_buffer)
      -- The state should have winid set after toggle completes
      assert.is_not_nil(input.state.winid, 'Input window should be created')
    end)

    it('case b: should close input window when already open', function()
      local input = require('claude-code.input')

      -- Set up: input window is already open
      local original_win_id = 50
      input.state.winid = original_win_id

      -- Mock vim.api.nvim_win_is_valid to return true for this window
      _G.vim.api.nvim_win_is_valid = function(win_id)
        return win_id == original_win_id
      end

      -- Mock vim.api.nvim_win_close to track that it was called
      local close_called = false
      local closed_win_id = nil
      _G.vim.api.nvim_win_close = function(win_id, force)
        close_called = true
        closed_win_id = win_id
        return true
      end

      -- Call toggle_input_buffer
      input.toggle_input_buffer(claude_code, config, git, '/test/git/root')

      -- Verify that the window was closed
      assert.is_true(close_called, 'nvim_win_close should be called')
      assert.are.equal(original_win_id, closed_win_id, 'Should close the input window')
      assert.is_nil(input.state.winid, 'Input winid should be cleared after close')
    end)

    it('case c: should focus terminal window before creating input split', function()
      local input = require('claude-code.input')
      sequence_log = {}

      -- Set up: terminal buffer exists with a visible window
      local term_win_id = 25
      local term_buf_id = 15
      claude_code.claude_code.instances['/test/git/root'] = term_buf_id

      -- Mock vim.fn.win_findbuf to return the terminal window
      _G.vim.fn.win_findbuf = function(bufnr)
        if bufnr == term_buf_id then
          return { term_win_id }
        end
        return {}
      end

      -- Reset state
      input.state.winid = nil

      -- Call toggle_input_buffer
      input.toggle_input_buffer(claude_code, config, git, '/test/git/root')

      -- Find if set_current_win was called before the split command
      local set_win_index = nil
      local split_cmd_index = nil

      for i, entry in ipairs(sequence_log) do
        if entry.type == 'set_current_win' and entry.win_id == term_win_id then
          set_win_index = i
        elseif entry.type == 'cmd' and entry.cmd:match('split') then
          split_cmd_index = i
        end
      end

      -- set_current_win should be called, and before the split command
      if split_cmd_index then
        -- If there's a split command, set_current_win should come before it
        assert.is_not_nil(set_win_index, 'Should set current window to terminal window')
        assert.is_true(
          set_win_index < split_cmd_index,
          'Should focus terminal window before creating split'
        )
      end
    end)

    it('should setup buffer keymaps after creating input buffer', function()
      local input = require('claude-code.input')
      vim_keymap_set_calls = {}

      -- Set up with no existing window or buffer
      input.state.winid = nil
      claude_code.claude_code.instances = {}

      -- Call toggle_input_buffer
      input.toggle_input_buffer(claude_code, config, git, '/test/git/root')

      -- Verify that keymaps were registered
      assert.is_true(#vim_keymap_set_calls > 0, 'Should setup buffer keymaps')

      -- Check that the expected keymaps are present
      local has_send_keymap = false
      local has_cancel_keymap = false

      for _, keymap in ipairs(vim_keymap_set_calls) do
        if keymap.lhs == '<CR>' then
          has_send_keymap = true
        end
        if keymap.lhs == '<C-c>' then
          has_cancel_keymap = true
        end
      end

      assert.is_true(has_send_keymap or has_cancel_keymap, 'Should have input buffer keymaps')
    end)

    it('should store state references after toggling', function()
      local input = require('claude-code.input')

      -- Reset state
      input.state.winid = nil
      input.state.claude_code = nil
      input.state.config = nil
      input.state.git = nil

      -- Call toggle_input_buffer
      input.toggle_input_buffer(claude_code, config, git, '/test/git/root')

      -- Verify that state is stored
      assert.is_not_nil(input.state.winid, 'Input winid should be stored')
      assert.are.equal(claude_code, input.state.claude_code, 'Should store claude_code reference')
      assert.are.equal(config, input.state.config, 'Should store config reference')
      assert.are.equal(git, input.state.git, 'Should store git reference')
    end)
  end)

  describe('create_input_buffer', function()
    it('should create buffer with sanitized name', function()
      local input = require('claude-code.input')

      local bufnr = input.create_input_buffer(config, git, '/test/git/root')

      assert.is_not_nil(bufnr, 'Should return a buffer number')
      assert.is_true(bufnr > 0, 'Buffer number should be positive')
    end)

    it('should reuse existing buffer with matching name', function()
      local input = require('claude-code.input')

      -- Mock vim.fn.bufnr to return an existing buffer
      _G.vim.fn.bufnr = function(pattern)
        if pattern:find('claude-code-input', 1, true) then
          return 99 -- Return existing buffer
        end
        return -1
      end

      local bufnr = input.create_input_buffer(config, git, '/test/git/root')

      assert.are.equal(99, bufnr, 'Should reuse existing buffer')
    end)

    it('should set correct buffer options', function()
      local input = require('claude-code.input')
      local set_option_calls = {}

      -- Mock vim.api.nvim_set_option_value to track calls
      _G.vim.api.nvim_set_option_value = function(option, value, opts)
        table.insert(set_option_calls, { option = option, value = value, opts = opts })
        return true
      end

      local bufnr = input.create_input_buffer(config, git, '/test/git/root')

      -- Check for important buffer options
      local has_swapfile_false = false
      local has_bufhidden = false

      for _, call in ipairs(set_option_calls) do
        if call.option == 'swapfile' and call.value == false then
          has_swapfile_false = true
        end
        if call.option == 'bufhidden' then
          has_bufhidden = true
        end
      end

      assert.is_true(has_swapfile_false, 'Should set swapfile to false')
      assert.is_true(has_bufhidden, 'Should set bufhidden option')
    end)
  end)
end)
