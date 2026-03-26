# clfind

Search and resume Claude Code sessions across all projects from the terminal.

Searches CLI sessions (`~/.claude/projects/`), global history, and Claude Desktop agent sessions.

## Install

```bash
cp clfind ~/.local/bin/clfind
chmod +x ~/.local/bin/clfind
```

Requires `~/.local/bin` in your `$PATH` and Python 3.

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

- **CLI sessions**: All `.jsonl` conversation files in `~/.claude/projects/`
- **Session indexes**: `sessions-index.json` files for indexed metadata
- **Desktop agent sessions**: `audit.jsonl` files from Claude Desktop's local-agent-mode
- **Deep mode**: Searches inside conversation content (user and assistant messages)

## Session actions

- **CLI sessions**: Resumes directly with `claude --resume` in the correct project directory
- **Desktop sessions**: Shows a conversation preview, with options to open the Desktop app or view the raw file
