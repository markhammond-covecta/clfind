# clfind

Search and resume Claude Code sessions across all projects from the terminal.

Searches CLI sessions (`~/.claude/projects/`), global history, and Claude Desktop agent sessions.

## Install

```bash
git clone https://github.com/markhammond-covecta/clfind.git
cd clfind
./install.sh
```

To upgrade, `git pull` and run `./install.sh` again.

## Requirements

- Python 3.9+
- macOS or Linux
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed (for session resume)

## Usage

```
clfind <query>             Search sessions (case-insensitive)
clfind <query> --deep      Also search conversation content (slower)
clfind --recent [N]        Show N most recent sessions (default 20)
clfind --list              List all sessions grouped by project
```

### Date filters

Filter sessions by last modified date. Use standalone or combine with a search query.

```
clfind --today             Sessions modified today
clfind --yesterday         Sessions modified yesterday
clfind --thisweek          Sessions modified this week (Mon-Sun)
clfind --lastweek          Sessions modified last week
clfind --thismonth         Sessions modified this month
clfind --lastmonth         Sessions modified last month
```

### Query syntax

```
word                       Matches if 'word' is found
'exact phrase'             Matches the exact phrase
A and B                    Both must match
A or B                     Either matches
not A                      A must not match
A B                        Implicit AND (both must match)
```

### Examples

```bash
clfind api deploy              # Sessions mentioning both 'api' and 'deploy'
clfind aws or azure            # Sessions mentioning either
clfind apple not 'apple pie'   # 'apple' but not the phrase 'apple pie'
clfind --recent 10             # Last 10 sessions across all projects
clfind --today                 # All sessions modified today
clfind api --thisweek          # 'api' sessions from this week
```

## What it searches

| Source | Location | Format |
|--------|----------|--------|
| CLI sessions | `~/.claude/projects/*/*.jsonl` | Conversation logs |
| Session indexes | `~/.claude/projects/*/sessions-index.json` | Indexed metadata |
| Desktop agent sessions | `~/Library/Application Support/Claude/local-agent-mode-sessions/**/audit.jsonl` | Agent audit logs |
| Deep mode (`--deep`) | Inside all the above | Full message content |

## Session actions

When you select a session:

- **CLI sessions** — resumes directly with `claude --resume` in the correct project directory
- **Desktop sessions** — shows a conversation preview in your terminal, with options to:
  - **[o]pen** the Claude Desktop app (with a search hint)
  - **[v]iew** the raw session file

## Configuration

### Extra arguments for `claude`

Set `CLFIND_CLAUDE_ARGUMENTS` to pass additional flags when resuming a session:

```bash
export CLFIND_CLAUDE_ARGUMENTS="--dangerously-skip-permissions"
```

Add this to your `~/.zshrc` (or `~/.bashrc`) to make it permanent. You can also set it via Claude Code's settings:

```json
// ~/.claude/settings.json
{
  "env": {
    "CLFIND_CLAUDE_ARGUMENTS": "--dangerously-skip-permissions"
  }
}
```
