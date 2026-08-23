# Project: Claude Code Plugin

## Overview

Claude Code Plugin provides seamless integration between the Claude Code AI assistant and Neovim. It enables direct communication with the Claude Code CLI from within the editor, context-aware interactions, and various utilities to enhance AI-assisted development within Neovim.

## Essential Commands

- Run Tests: `env -C /home/gregg/Projects/neovim/plugins/claude-code lua tests/run_tests.lua`
- Check Formatting: `env -C /home/gregg/Projects/neovim/plugins/claude-code stylua lua/ -c`
- Format Code: `env -C /home/gregg/Projects/neovim/plugins/claude-code stylua lua/`
- Run Linter: `env -C /home/gregg/Projects/neovim/plugins/claude-code luacheck lua/`
- Build Documentation: `env -C /home/gregg/Projects/neovim/plugins/claude-code mkdocs build`

## Project Structure

- `/lua/claude-code`: Main plugin code
- `/lua/claude-code/cli`: Claude Code CLI integration
- `/lua/claude-code/ui`: UI components for interactions
- `/lua/claude-code/context`: Context management utilities
- `/after/plugin`: Plugin setup and initialization
- `/tests`: Test files for plugin functionality
- `/doc`: Vim help documentation

## Current Focus

- Integrating nvim-toolkit for shared utilities
- Adding hooks-util as git submodule for development workflow
- Enhancing bidirectional communication with Claude Code CLI
- Implementing better context synchronization
- Adding buffer-specific context management

## Multi-Instance Support

The plugin supports running multiple Claude Code instances, one per git repository root:

- Each git repository maintains its own Claude instance
- Works across multiple Neovim tabs with different projects
- Allows working on multiple projects in parallel
- Configurable via `git.multi_instance` option (defaults to `true`)
- Instances remain in their own directory context when switching between tabs
- Buffer names include the git root path for easy identification

Example configuration to disable multi-instance mode:

```lua
require('claude-code').setup({
  git = {
    multi_instance = false  -- Use a single global Claude instance
  }
})
```

## Documentation Links

- Tasks: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/tasks/claude-code-tasks.md`
- Project Status: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/project-status.md`


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
