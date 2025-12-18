# Claude Code ACP Plugin Design

## Overview
New Neovim plugin (`claude-code-acp.nvim`) that integrates Claude Code directly into Neovim without terminal friction. Leverages the claude-code-acp Node.js adapter to provide ACP (Agent Client Protocol) communication with Claude Code backend.

## Architecture Overview

**Plugin structure:**
- New plugin: `claude-code-acp.nvim` (separate from existing claude-code.nvim)
- Spawns claude-code-acp Node.js process as a subprocess (stdio-based communication)
- Neovim translates user actions (chat, selections, commands) into ACP messages
- ACP subprocess handles Claude sessions, tool execution, terminals
- Responses flow back into Neovim UI components (chat panel, inline edits, diagnostics)

**Communication flow:**
1. User opens chat panel, types message with context from current buffer
2. Neovim builds ACP message (includes buffer content, selected ranges, file paths)
3. Sends to claude-code-acp subprocess via stdin/socket
4. ACP subprocess talks to Claude API, executes tools as needed
5. Results stream back: text messages, file edits, terminal output
6. Neovim renders in chat window, applies edits directly to buffers

**Key advantage:** Claude Code's tool execution (`:grep`, `:edit`, `:terminal`) runs in the subprocess context (the git repo root), not in Neovim. Neovim just displays results and applies changes.

## UI Components & User Workflows

**Main UI elements:**
- **Chat panel** - Floating/split window with conversation history, user input at bottom, streaming Claude responses
- **Buffer integration** - Selected code automatically included in context (like avante), option to `@-mention` specific files
- **Inline edits** - When Claude suggests changes, show diff preview; accept/reject before applying to buffer
- **Context picker** - UI to select which files/buffers contribute to context (visual confirmation of what Claude sees)
- **Terminal output** - Floating window for long-running operations (tool execution, terminal sessions)

**Workflows:**
1. **Chat-based** - `:ClaudeCode` opens panel, type questions, Claude responds with context from current buffer/selection
2. **Command-based** - `:ClaudeCode explain`, `:ClaudeCode refactor`, `:ClaudeCode test` trigger specific tasks
3. **Selection-based** - Highlight code, `:ClaudeCode <action>` operates on selection
4. **File operations** - Claude can suggest edits across multiple files; Neovim shows diffs, user confirms

## Data Flow & State Management

**Message protocol:**
- Neovim serializes user actions to ACP messages (JSON-based per Agent Client Protocol spec)
- Claude-code-acp subprocess receives, processes, streams responses back
- Neovim maintains session state per repository (multi-instance support like current plugin)

**State to track:**
- Active ACP subprocess per git repository root
- Current conversation/session ID
- Open windows (chat panel, edit previews, terminal output)
- Buffer change subscriptions (auto-update context when user edits)
- Pending edits awaiting user confirmation

**Error handling:**
- ACP subprocess crashes → graceful reconnect with state recovery
- Claude API errors → display in chat panel, allow retry
- Tool execution failures → show error in terminal output window, logged
- Neovim buffer out-of-sync with subprocess knowledge → conflict resolution UI

**Threading:**
- Spawn ACP as background job (vim.loop/uv for async I/O)
- Stream responses to avoid blocking Neovim on long operations
- Queue user messages if subprocess busy (prevents lost input)

## Testing & Implementation Priorities

**Testing strategy:**
- Unit tests for Lua ACP message builders (ensure correct JSON serialization)
- Integration tests mocking ACP subprocess responses (test UI rendering without real Claude calls)
- E2E tests spawning real ACP subprocess (verify end-to-end workflows)
- Test fixtures for common scenarios (chat flow, edit acceptance, error states)

**Implementation priorities (Phase 1):**
1. Scaffold plugin structure, ACP subprocess spawning/lifecycle
2. Basic chat panel UI with message streaming
3. Context management (buffer content → ACP context)
4. Edit preview & acceptance flow
5. Multi-instance per git repo support

**Phase 2 (future):**
- Terminal output window for tool execution
- Command palette shortcuts (`:ClaudeCode explain`, etc.)
- Context picker UI for file selection
- Persistent session/history

**Dependencies:**
- Claude-code-acp Node package (npm install, distribute with plugin)
- plenary.nvim (async job handling, already likely available)
- UI library (nui.nvim for floating windows, or similar)
