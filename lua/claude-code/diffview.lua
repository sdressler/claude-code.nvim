---@mod claude-code.diffview Diff preview for Claude Code edits
---@brief [[
--- Opens a diff view before Claude Code applies a file edit.
--- Tries diffview.nvim first; falls back to a plain vimdiff tab.
---
--- Called from the PreToolUse hook script via:
---   nvim --server $NVIM --remote-expr
---     "luaeval('require(\"claude-code.diffview\").show_diff(\"/path/to/args.json\")')"
---@brief ]]

local M = {}

-- Track the window we opened so close_diff can target it precisely.
local state = {
  diff_win = nil, -- window handle for the proposed-content split
  orig_win = nil, -- window handle for the original file
  prev_bufnr = nil, -- buffer that was in orig_win before we loaded original
  tmp_path = nil, -- temp file to delete on cleanup
  args_path = nil, -- args json file to delete on cleanup
}

--- Read JSON args file written by the hook script.
--- @param args_path string path to the .args.json file
--- @return table|nil parsed, string|nil err
local function read_args(args_path)
  local f = io.open(args_path, 'r')
  if not f then
    return nil, 'cannot open args file: ' .. args_path
  end
  local raw = f:read('*a')
  f:close()
  local ok, parsed = pcall(vim.json.decode, raw)
  if not ok then
    return nil, 'json decode error: ' .. tostring(parsed)
  end
  return parsed, nil
end

--- Open a plain vimdiff split in the current tab.
--- Original file must already be open (or will be opened) in a window;
--- proposed content opens as a vertical split to the right.
--- @param original string absolute path to the current file
--- @param proposed string absolute path to the temp proposed file
local function open_vimdiff(original, proposed)
  -- Prefer window already showing the original file; else pick first
  -- non-terminal window so we don't clobber the CC terminal.
  local orig_win = nil
  local orig_bufnr = vim.fn.bufnr(original)
  if orig_bufnr ~= -1 then
    local win = vim.fn.bufwinid(orig_bufnr)
    if win ~= -1 then
      orig_win = win
    end
  end
  if not orig_win then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local bt = vim.api.nvim_get_option_value('buftype', { buf = vim.api.nvim_win_get_buf(win) })
      if bt ~= 'terminal' then
        orig_win = win
        break
      end
    end
  end
  if not orig_win then
    vim.notify('[claude-code] diffview: no non-terminal window found', vim.log.levels.WARN)
    return
  end

  -- Switch to that window and load the original file if not already there
  vim.api.nvim_set_current_win(orig_win)
  local cur_buf = vim.api.nvim_win_get_buf(orig_win)
  if vim.api.nvim_buf_get_name(cur_buf) ~= original then
    -- Save current buffer so we can restore it on cleanup
    state.prev_bufnr = cur_buf
    vim.cmd('edit ' .. vim.fn.fnameescape(original))
  else
    state.prev_bufnr = nil
  end
  state.orig_win = vim.api.nvim_get_current_win()

  -- Enable diff on the original side
  vim.cmd('diffthis')

  -- Open proposed content in a vertical split to the right
  vim.cmd('rightbelow vsplit ' .. vim.fn.fnameescape(proposed))
  state.diff_win = vim.api.nvim_get_current_win()
  vim.bo.modifiable = false
  vim.bo.bufhidden = 'wipe'
  vim.cmd('diffthis')

  -- Return focus to original window
  vim.api.nvim_set_current_win(state.orig_win)
end

--- Close any open diff and clean up temp files (runs immediately, no schedule).
--- @private
local function do_close_diff()
  -- Remember the CC terminal window to restore focus after cleanup
  local term_win = nil
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bt = vim.api.nvim_get_option_value('buftype', { buf = vim.api.nvim_win_get_buf(win) })
    if bt == 'terminal' then
      term_win = win
      break
    end
  end

  if state.orig_win and vim.api.nvim_win_is_valid(state.orig_win) then
    vim.api.nvim_win_call(state.orig_win, function()
      vim.cmd('diffoff')
      -- Restore whatever buffer was there before we loaded the original file
      if state.prev_bufnr and vim.api.nvim_buf_is_valid(state.prev_bufnr) then
        vim.api.nvim_win_set_buf(state.orig_win, state.prev_bufnr)
      end
    end)
  end
  -- Close the proposed-content split
  if state.diff_win and vim.api.nvim_win_is_valid(state.diff_win) then
    vim.api.nvim_win_close(state.diff_win, true)
  end
  state.diff_win = nil
  state.orig_win = nil
  state.prev_bufnr = nil

  -- Restore focus to CC terminal
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_set_current_win(term_win)
  end

  if state.tmp_path then
    pcall(os.remove, state.tmp_path)
    state.tmp_path = nil
  end
  if state.args_path then
    pcall(os.remove, state.args_path)
    state.args_path = nil
  end
end

--- Public: show diff. Called by the hook via --remote-expr.
--- @param args_path string path to the args json file
--- @return number 0 always (remote-expr needs a return value)
function M.show_diff(args_path)
  local args, err = read_args(args_path)
  if not args then
    vim.schedule(function()
      vim.notify('[claude-code] diffview: ' .. (err or 'unknown error'), vim.log.levels.WARN)
    end)
    return 0
  end

  local original = args.original
  local proposed = args.proposed

  state.tmp_path = proposed
  state.args_path = args_path

  vim.schedule(function()
    do_close_diff()

    -- diffview.nvim doesn't support arbitrary non-git files via DiffviewOpen;
    -- vimdiff works everywhere.
    open_vimdiff(original, proposed)
  end)

  return 0
end

--- Public: close the diff view. Called by the PostToolUse hook via --remote-expr.
--- @return number 0
function M.close_diff()
  vim.schedule(do_close_diff)
  return 0
end

return M
