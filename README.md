# clfind

Search and resume Claude Code sessions across all projects from the terminal.

Searches CLI sessions (`~/.claude/projects/`), global history, and Claude Desktop agent sessions.

## Install

> **Private repo** — you need access to `markhammond-covecta/clfind`. Ask Mark for an invite.

### One-liner (recommended)

Requires [GitHub CLI](https://cli.github.com/) (`brew install gh`):

```bash
gh repo clone markhammond-covecta/clfind /tmp/clfind && mkdir -p ~/.local/bin && cp /tmp/clfind/clfind ~/.local/bin/clfind && chmod +x ~/.local/bin/clfind && rm -rf /tmp/clfind && echo "Installed! Run: clfind --help"
```

If `~/.local/bin` is not in your PATH, add it:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

### Alternative: uv / pipx

If you use [uv](https://docs.astral.sh/uv/) or [pipx](https://pypa.github.io/pipx/), these automatically manage PATH for you:

```bash
uv tool install git+https://github.com/markhammond-covecta/clfind.git
# or
pipx install git+https://github.com/markhammond-covecta/clfind.git
```

### Upgrade

```bash
gh repo clone markhammond-covecta/clfind /tmp/clfind && cp /tmp/clfind/clfind ~/.local/bin/clfind && rm -rf /tmp/clfind
```

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
