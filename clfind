#!/usr/bin/env python3
"""clfind - Search and resume Claude Code sessions across all projects.

Usage:
    clfind <query>             Search sessions (case-insensitive)
    clfind <query> --deep      Also search conversation content (slower)
    clfind --recent [N]        Show N most recent sessions (default 20)
    clfind --list              List all sessions grouped by project

Query syntax:
    word                       Matches if 'word' is found
    'exact phrase'             Matches the exact phrase
    A and B                    Both must match
    A or B                     Either matches
    not A                      A must not match
    A B                        Implicit AND (both must match)

Examples:
    clfind api deploy          Sessions mentioning both 'api' and 'deploy'
    clfind aws or azure        Sessions mentioning either
    clfind apple not 'apple pie'   'apple' but not 'apple pie'
"""

import json
import os
import sys
import subprocess
import re
from datetime import datetime, timezone
from pathlib import Path

# --- Configuration ---
CLAUDE_DIR = Path.home() / ".claude"
PROJECTS_DIR = CLAUDE_DIR / "projects"
HISTORY_FILE = CLAUDE_DIR / "history.jsonl"
DESKTOP_SESSIONS = Path.home() / "Library" / "Application Support" / "Claude" / "local-agent-mode-sessions"

# ANSI colors
BOLD = "\033[1m"
DIM = "\033[2m"
CYAN = "\033[36m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
MAGENTA = "\033[35m"
BLUE = "\033[34m"
RED = "\033[31m"
RESET = "\033[0m"


def decode_project_name(encoded: str) -> str:
    """Convert '-Users-mark-code-toolhub' back to '/Users/mark/code/toolhub'."""
    return encoded.replace("-", "/", 1).replace("-", "/")


def friendly_project(path: str) -> str:
    """Shorten project path for display."""
    home = str(Path.home())
    if path.startswith(home):
        return "~" + path[len(home):]
    return path


def format_date(iso_or_ts) -> str:
    """Format ISO string or millisecond timestamp to readable date."""
    try:
        if isinstance(iso_or_ts, (int, float)):
            dt = datetime.fromtimestamp(iso_or_ts / 1000, tz=timezone.utc)
        else:
            iso_or_ts = str(iso_or_ts).replace("Z", "+00:00")
            dt = datetime.fromisoformat(iso_or_ts)
        now = datetime.now(tz=timezone.utc)
        delta = now - dt
        if delta.days == 0:
            return "today"
        elif delta.days == 1:
            return "yesterday"
        elif delta.days < 7:
            return f"{delta.days}d ago"
        elif delta.days < 30:
            return f"{delta.days // 7}w ago"
        else:
            return dt.strftime("%Y-%m-%d")
    except Exception:
        return "?"


def clean_prompt(text: str) -> str:
    """Remove XML tags and system noise from prompt text."""
    # Strip XML-style tags and their content for known noise patterns
    text = re.sub(r"<(?:command-message|command-name|local-command-caveat|ide_opened_file|ide_selection|system-reminder)[^>]*>.*?</(?:command-message|command-name|local-command-caveat|ide_opened_file|ide_selection|system-reminder)>", "", text, flags=re.DOTALL)
    # Strip any remaining self-closing or unclosed XML tags
    text = re.sub(r"<[^>]+>", " ", text)
    # Collapse whitespace
    text = re.sub(r"\s+", " ", text).strip()
    return text


def truncate(text: str, width: int) -> str:
    """Truncate text to width with ellipsis."""
    text = text.replace("\n", " ").strip()
    if len(text) <= width:
        return text
    return text[: width - 1] + "\u2026"


def get_first_prompt_from_jsonl(jsonl_path: str) -> tuple:
    """Extract first user prompt and metadata from a JSONL session file.
    Returns (first_prompt, session_id, created_ts, modified_ts, project_path, git_branch).
    """
    first_prompt = None
    session_id = None
    created = None
    modified = None
    project_path = None
    git_branch = None

    try:
        with open(jsonl_path, "r", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                if not session_id:
                    session_id = entry.get("sessionId") or entry.get("session_id")
                if not created:
                    created = entry.get("timestamp") or entry.get("_audit_timestamp")
                if not project_path and entry.get("cwd"):
                    project_path = entry.get("cwd")
                if not git_branch and entry.get("gitBranch"):
                    git_branch = entry.get("gitBranch")

                msg_type = entry.get("type", "")
                if msg_type == "user" and not first_prompt:
                    msg = entry.get("message", {})
                    content = msg.get("content", "")
                    if isinstance(content, list):
                        # Handle structured content blocks
                        text_parts = [
                            b.get("text", "")
                            for b in content
                            if isinstance(b, dict) and b.get("type") == "text"
                        ]
                        content = " ".join(text_parts)
                    if content and not content.startswith("<"):
                        first_prompt = content
                        break  # Got what we need
                    elif content:
                        first_prompt = content[:200]
                        break
    except (OSError, PermissionError):
        pass

    # Get modified time from file
    try:
        modified = os.path.getmtime(jsonl_path)
        modified = datetime.fromtimestamp(modified, tz=timezone.utc).isoformat()
    except OSError:
        pass

    return (first_prompt, session_id, created, modified, project_path, git_branch)


def search_jsonl_content(jsonl_path: str, keyword_pattern) -> list:
    """Search conversation content for keyword matches. Returns matching snippets."""
    matches = []
    try:
        with open(jsonl_path, "r", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                msg_type = entry.get("type", "")
                if msg_type not in ("user", "assistant"):
                    continue
                msg = entry.get("message", {})
                content = msg.get("content", "")
                if isinstance(content, list):
                    text_parts = [
                        b.get("text", "")
                        for b in content
                        if isinstance(b, dict) and b.get("type") == "text"
                    ]
                    content = " ".join(text_parts)
                if keyword_pattern.search(content):
                    snippet = content[:150].replace("\n", " ").strip()
                    matches.append((msg_type, snippet))
                    if len(matches) >= 3:
                        break
    except (OSError, PermissionError):
        pass
    return matches


def collect_sessions_from_indexes():
    """Collect sessions from all sessions-index.json files."""
    sessions = {}  # keyed by sessionId

    if not PROJECTS_DIR.exists():
        return sessions

    for index_file in PROJECTS_DIR.glob("*/sessions-index.json"):
        try:
            with open(index_file) as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError):
            continue

        original_path = data.get("originalPath", "")
        for entry in data.get("entries", []):
            sid = entry.get("sessionId", "")
            if not sid:
                continue
            sessions[sid] = {
                "sessionId": sid,
                "firstPrompt": entry.get("firstPrompt", ""),
                "created": entry.get("created", ""),
                "modified": entry.get("modified", ""),
                "projectPath": entry.get("projectPath", original_path),
                "gitBranch": entry.get("gitBranch", ""),
                "messageCount": entry.get("messageCount", 0),
                "fullPath": entry.get("fullPath", ""),
                "source": "cli",
                "name": entry.get("name", ""),
            }

    return sessions


def collect_sessions_from_jsonl_files(indexed_sessions):
    """Scan JSONL files not already in indexes."""
    sessions = {}

    if not PROJECTS_DIR.exists():
        return sessions

    for jsonl_file in PROJECTS_DIR.glob("*/*.jsonl"):
        # Skip subagent files
        if "/subagents/" in str(jsonl_file):
            continue

        # Extract session ID from filename
        sid = jsonl_file.stem
        if sid in indexed_sessions:
            continue

        # Derive project from parent dir name
        project_dir = jsonl_file.parent.name
        project_path = decode_project_name(project_dir)

        prompt, file_sid, created, modified, cwd, branch = get_first_prompt_from_jsonl(
            str(jsonl_file)
        )
        actual_sid = file_sid or sid

        sessions[actual_sid] = {
            "sessionId": actual_sid,
            "firstPrompt": prompt or "(no prompt found)",
            "created": created or "",
            "modified": modified or "",
            "projectPath": cwd or project_path,
            "gitBranch": branch or "",
            "messageCount": 0,
            "fullPath": str(jsonl_file),
            "source": "cli",
            "name": "",
        }

    return sessions


def collect_desktop_sessions():
    """Collect sessions from Claude Desktop local-agent-mode."""
    sessions = {}

    if not DESKTOP_SESSIONS.exists():
        return sessions

    # Find audit.jsonl files (Desktop agent sessions)
    for audit_file in DESKTOP_SESSIONS.glob("**/audit.jsonl"):
        prompt, sid, created, modified, cwd, branch = get_first_prompt_from_jsonl(
            str(audit_file)
        )
        if not sid:
            sid = audit_file.parent.name
        if not prompt:
            continue

        sessions[sid] = {
            "sessionId": sid,
            "firstPrompt": prompt or "(no prompt)",
            "created": created or "",
            "modified": modified or "",
            "projectPath": cwd or "(desktop agent)",
            "gitBranch": branch or "",
            "messageCount": 0,
            "fullPath": str(audit_file),
            "source": "desktop",
            "name": "",
        }

    # Find sessions-index.json inside Desktop sandboxes
    for index_file in DESKTOP_SESSIONS.glob("**/sessions-index.json"):
        try:
            with open(index_file) as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError):
            continue

        for entry in data.get("entries", []):
            sid = entry.get("sessionId", "")
            if not sid or sid in sessions:
                continue
            sessions[sid] = {
                "sessionId": sid,
                "firstPrompt": entry.get("firstPrompt", ""),
                "created": entry.get("created", ""),
                "modified": entry.get("modified", ""),
                "projectPath": entry.get("projectPath", "(desktop)"),
                "gitBranch": entry.get("gitBranch", ""),
                "messageCount": entry.get("messageCount", 0),
                "fullPath": entry.get("fullPath", ""),
                "source": "desktop",
                "name": entry.get("name", ""),
            }

    return sessions


def collect_history_entries():
    """Collect entries from global history.jsonl."""
    entries = []
    if not HISTORY_FILE.exists():
        return entries

    try:
        with open(HISTORY_FILE, "r", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    entries.append(entry)
                except json.JSONDecodeError:
                    continue
    except OSError:
        pass

    return entries


class Query:
    """Boolean search query with AND, OR, NOT and quoted phrases.

    Syntax:
        word              — matches if 'word' is found (case-insensitive)
        'quoted phrase'   — matches the exact phrase
        "quoted phrase"   — same
        A and B           — both must match
        A or B            — either must match
        not A             — A must not match
        A B               — implicit AND (both must match)

    Operator precedence: NOT > AND > OR.  Parentheses are not supported.
    """

    def __init__(self, raw: str):
        self.raw = raw
        self._tree = self._parse(raw)
        # Collect positive terms for highlighting
        self.highlight_terms = self._collect_positives(self._tree)

    # --- tokeniser ---
    @staticmethod
    def _tokenise(text: str) -> list:
        tokens = []
        i = 0
        while i < len(text):
            c = text[i]
            if c in ("'", '"'):
                # Quoted phrase
                end = text.find(c, i + 1)
                if end == -1:
                    end = len(text)
                tokens.append(("TERM", text[i + 1 : end].lower()))
                i = end + 1
            elif c.isspace():
                i += 1
            else:
                # Unquoted word — read until space or quote
                j = i
                while j < len(text) and not text[j].isspace() and text[j] not in ("'", '"'):
                    j += 1
                word = text[i:j].lower()
                if word == "and":
                    tokens.append(("AND",))
                elif word == "or":
                    tokens.append(("OR",))
                elif word == "not":
                    tokens.append(("NOT",))
                else:
                    tokens.append(("TERM", word))
                i = j
        return tokens

    # --- parser (recursive descent: OR < AND < NOT < TERM) ---
    def _parse(self, text: str):
        self._tokens = self._tokenise(text)
        self._pos = 0
        if not self._tokens:
            return ("TERM", "")
        tree = self._parse_or()
        return tree

    def _peek(self):
        return self._tokens[self._pos] if self._pos < len(self._tokens) else None

    def _parse_or(self):
        left = self._parse_and()
        while self._peek() and self._peek()[0] == "OR":
            self._pos += 1
            right = self._parse_and()
            left = ("OR", left, right)
        return left

    def _parse_and(self):
        left = self._parse_not()
        while self._peek() and self._peek()[0] in ("AND", "TERM", "NOT"):
            # Explicit AND or implicit AND (adjacent terms)
            if self._peek()[0] == "AND":
                self._pos += 1
            right = self._parse_not()
            left = ("AND", left, right)
        return left

    def _parse_not(self):
        if self._peek() and self._peek()[0] == "NOT":
            self._pos += 1
            operand = self._parse_not()
            return ("NOT", operand)
        return self._parse_term()

    def _parse_term(self):
        tok = self._peek()
        if tok and tok[0] == "TERM":
            self._pos += 1
            return ("TERM", tok[1])
        # Unexpected token — treat as empty match
        return ("TERM", "")

    # --- evaluation ---
    def matches(self, text: str) -> bool:
        """Test if text matches this query."""
        return self._eval(self._tree, text.lower())

    def _eval(self, node, text: str) -> bool:
        op = node[0]
        if op == "TERM":
            term = node[1]
            return term in text if term else True
        elif op == "AND":
            return self._eval(node[1], text) and self._eval(node[2], text)
        elif op == "OR":
            return self._eval(node[1], text) or self._eval(node[2], text)
        elif op == "NOT":
            return not self._eval(node[1], text)
        return False

    def _collect_positives(self, node) -> list:
        """Collect positive (non-negated) terms for highlighting."""
        op = node[0]
        if op == "TERM":
            return [node[1]] if node[1] else []
        elif op == "NOT":
            return []  # Don't highlight negated terms
        elif op in ("AND", "OR"):
            return self._collect_positives(node[1]) + self._collect_positives(node[2])
        return []

    def __str__(self):
        return self.raw


def match_session(session: dict, query: Query) -> bool:
    """Check if a session matches the query."""
    searchable = " ".join([
        session.get("firstPrompt", ""),
        session.get("name", ""),
        session.get("projectPath", ""),
        session.get("gitBranch", ""),
    ])
    return query.matches(searchable)


def deep_match_session(session: dict, query: Query) -> list:
    """Deep search inside conversation JSONL for query matches."""
    full_path = session.get("fullPath", "")
    if not full_path or not os.path.exists(full_path):
        return []
    # Build a regex from positive terms for snippet extraction
    terms = query.highlight_terms
    if not terms:
        return []
    pattern = re.compile("|".join(re.escape(t) for t in terms), re.IGNORECASE)
    return search_jsonl_content(full_path, pattern)


def sort_by_date(sessions: list) -> list:
    """Sort sessions by modified date, most recent first."""
    def sort_key(s):
        mod = s.get("modified", "") or s.get("created", "")
        if not mod:
            return ""
        try:
            if isinstance(mod, (int, float)):
                return datetime.fromtimestamp(mod / 1000, tz=timezone.utc).isoformat()
            return mod
        except Exception:
            return ""
    return sorted(sessions, key=sort_key, reverse=True)


def display_sessions(results: list, query=None, deep_matches: dict = None):
    """Display session results with interactive selection."""
    if not results:
        print(f"{RED}No sessions found.{RESET}")
        return None

    print(f"\n{BOLD}Found {len(results)} session(s){RESET}", end="")
    if query:
        print(f" matching {CYAN}\"{query}\"{RESET}", end="")
    print(f":\n")

    # Build highlight pattern from query's positive terms
    highlight_pattern = None
    if query and hasattr(query, 'highlight_terms') and query.highlight_terms:
        highlight_pattern = re.compile(
            "|".join(re.escape(t) for t in query.highlight_terms),
            re.IGNORECASE
        )

    for i, s in enumerate(results, 1):
        prompt = s.get("name") or s.get("firstPrompt", "(empty)")
        prompt = clean_prompt(prompt)
        if not prompt:
            prompt = "(empty)"
        prompt = truncate(prompt, 80)
        project = friendly_project(s.get("projectPath", ""))
        date = format_date(s.get("modified") or s.get("created"))
        source_tag = f" {MAGENTA}[desktop]{RESET}" if s.get("source") == "desktop" else ""
        branch = s.get("gitBranch", "")
        branch_str = f" {DIM}({branch}){RESET}" if branch and branch != "HEAD" else ""
        msg_count = s.get("messageCount", 0)
        msg_str = f" {DIM}{msg_count}msg{RESET}" if msg_count else ""

        # Number
        num = f"{BOLD}{CYAN}{i:>3}{RESET}"
        # Date
        date_str = f"{DIM}{date:>10}{RESET}"
        # Highlight positive search terms
        if highlight_pattern:
            prompt = highlight_pattern.sub(f"{YELLOW}\\g<0>{RESET}", prompt)

        print(f"  {num}  {date_str}  {prompt}{source_tag}")
        print(f"       {DIM}{project}{branch_str}{msg_str}{RESET}")

        # Show deep match snippets if available
        if deep_matches and s["sessionId"] in deep_matches:
            for msg_type, snippet in deep_matches[s["sessionId"]][:2]:
                role = "you" if msg_type == "user" else "claude"
                print(f"       {DIM}  [{role}] {truncate(snippet, 70)}{RESET}")

        print()

    return results


def select_session(results: list) -> dict:
    """Prompt user to select a session."""
    if not results:
        return None

    print(f"{BOLD}Enter number to resume, or q to quit:{RESET} ", end="", flush=True)
    try:
        choice = input().strip()
    except (EOFError, KeyboardInterrupt):
        print()
        return None

    if choice.lower() in ("q", "quit", ""):
        return None

    try:
        idx = int(choice) - 1
        if 0 <= idx < len(results):
            return results[idx]
        else:
            print(f"{RED}Invalid selection.{RESET}")
            return None
    except ValueError:
        print(f"{RED}Invalid input.{RESET}")
        return None


def preview_conversation(session: dict, max_messages: int = 20):
    """Show a conversation preview from a session's JSONL file."""
    full_path = session.get("fullPath", "")
    if not full_path or not os.path.exists(full_path):
        print(f"{DIM}(conversation file not found){RESET}")
        return

    messages = []
    try:
        with open(full_path, "r", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                msg_type = entry.get("type", "")
                if msg_type not in ("user", "assistant"):
                    continue
                msg = entry.get("message", {})
                content = msg.get("content", "")
                if isinstance(content, list):
                    text_parts = [
                        b.get("text", "")
                        for b in content
                        if isinstance(b, dict) and b.get("type") == "text"
                    ]
                    content = " ".join(text_parts)
                content = clean_prompt(content).strip()
                if not content:
                    continue
                messages.append((msg_type, content))
    except (OSError, PermissionError):
        print(f"{DIM}(could not read conversation file){RESET}")
        return

    if not messages:
        print(f"{DIM}(no messages found){RESET}")
        return

    # Get terminal width
    try:
        term_width = os.get_terminal_size().columns
    except OSError:
        term_width = 80
    content_width = min(term_width - 12, 100)

    print(f"\n{BOLD}Conversation preview{RESET} ({len(messages)} messages):\n")
    for msg_type, content in messages[:max_messages]:
        if msg_type == "user":
            label = f"  {GREEN}{BOLD}you{RESET}  "
        else:
            label = f"  {BLUE}{BOLD}claude{RESET}"
        # Wrap long content to multiple lines
        lines = []
        words = content.split()
        current = ""
        for word in words:
            if len(current) + len(word) + 1 <= content_width:
                current = f"{current} {word}" if current else word
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)
        if not lines:
            continue

        # Truncate very long messages
        if len(lines) > 6:
            lines = lines[:5]
            lines.append(f"{DIM}[...]{RESET}")

        print(f"{label}  {lines[0]}")
        for extra_line in lines[1:]:
            print(f"          {extra_line}")
        print()

    if len(messages) > max_messages:
        print(f"  {DIM}... and {len(messages) - max_messages} more messages{RESET}\n")


def open_desktop_session(search_query: str):
    """Open Claude Desktop and tell the user what to search for."""
    subprocess.run(["open", "-a", "Claude"], check=False)
    print(f"{GREEN}Opened Claude Desktop.{RESET}")
    print(f"{DIM}Press {BOLD}Cmd+K{RESET}{DIM} and search for:{RESET} {CYAN}{search_query}{RESET}")


def resume_session(session: dict):
    """Resume a selected session."""
    sid = session["sessionId"]
    source = session.get("source", "cli")
    project = session.get("projectPath", "")

    if source == "desktop":
        print(f"\n{YELLOW}Desktop app session{RESET}")

        preview_conversation(session)

        # Build a search query from the first prompt
        search_query = session.get("firstPrompt", "")
        search_query = clean_prompt(search_query)[:40].strip()

        options = []
        if search_query:
            options.append(f"{BOLD}[o]{RESET}pen in Desktop (searches sidebar)")
        options.append(f"{BOLD}[v]{RESET}iew full file")
        options.append(f"{BOLD}[q]{RESET}uit")
        print("  ".join(options) + ": ", end="", flush=True)
        try:
            action = input().strip().lower()
        except (EOFError, KeyboardInterrupt):
            print()
            return

        if action == "o" and search_query:
            open_desktop_session(search_query)
        elif action == "v":
            full_path = session.get("fullPath", "")
            if full_path:
                os.execlp("less", "less", full_path)
        return

    print(f"\n{GREEN}Resuming session...{RESET}")
    print(f"{DIM}Session: {sid}{RESET}")
    if project:
        print(f"{DIM}Project: {project}{RESET}")
    print()

    # Change to the project directory so claude opens in the right context
    if project and os.path.isdir(project):
        os.chdir(project)

    cmd = ["claude", "--resume", sid]
    extra = os.environ.get("CLFIND_CLAUDE_ARGUMENTS", "")
    if extra:
        cmd.extend(extra.split())
    os.execvp("claude", cmd)


def main():
    args = sys.argv[1:]

    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        sys.exit(0)

    deep = "--deep" in args
    recent_mode = "--recent" in args
    list_mode = "--list" in args

    # Remove flags from args.
    # Re-quote any arg containing spaces — the shell already stripped the user's
    # quotes, but a multi-word arg means the user quoted it as a phrase.
    keyword_parts = []
    for a in args:
        if a.startswith("--"):
            continue
        if " " in a:
            keyword_parts.append(f"'{a}'")
        else:
            keyword_parts.append(a)
    keyword = " ".join(keyword_parts).strip()

    # --- Collect all sessions ---
    print(f"{DIM}Scanning sessions...{RESET}", end="", flush=True)

    indexed = collect_sessions_from_indexes()
    unindexed = collect_sessions_from_jsonl_files(indexed)
    desktop = collect_desktop_sessions()

    all_sessions = {}
    all_sessions.update(indexed)
    all_sessions.update(unindexed)
    all_sessions.update(desktop)

    total = len(all_sessions)
    print(f"\r{DIM}Found {total} sessions across {len(set(s.get('projectPath','') for s in all_sessions.values()))} projects.{RESET}")

    # --- List mode ---
    if list_mode:
        by_project = {}
        for s in all_sessions.values():
            p = s.get("projectPath", "(unknown)")
            by_project.setdefault(p, []).append(s)

        for project, sessions in sorted(by_project.items()):
            sessions = sort_by_date(sessions)
            print(f"\n{BOLD}{friendly_project(project)}{RESET} ({len(sessions)} sessions)")
            for s in sessions[:5]:
                prompt = clean_prompt(s.get("firstPrompt", ""))
                prompt = truncate(prompt or "(empty)", 60)
                date = format_date(s.get("modified") or s.get("created"))
                print(f"  {DIM}{date:>10}{RESET}  {prompt}")
            if len(sessions) > 5:
                print(f"  {DIM}... and {len(sessions) - 5} more{RESET}")
        print()
        return

    # --- Recent mode ---
    if recent_mode:
        n = 20
        if keyword.isdigit():
            n = int(keyword)
        results = sort_by_date(list(all_sessions.values()))[:n]
        results = display_sessions(results)
        if results:
            selected = select_session(results)
            if selected:
                resume_session(selected)
        return

    # --- Search mode ---
    if not keyword:
        print(f"{RED}Please provide a search keyword.{RESET}")
        print("Usage: clfind <keyword>")
        sys.exit(1)

    query = Query(keyword)

    # Filter by query
    results = [
        s for s in all_sessions.values()
        if match_session(s, query)
    ]

    deep_matches = {}
    if deep and not results:
        # Deep search: scan conversation content
        print(f"{DIM}No matches in titles/projects. Deep searching conversation content...{RESET}")
        for sid, s in all_sessions.items():
            matches = deep_match_session(s, query)
            if matches:
                results.append(s)
                deep_matches[sid] = matches
    elif deep:
        # Also add deep matches for already-matched sessions
        for s in list(all_sessions.values()):
            if s["sessionId"] not in {r["sessionId"] for r in results}:
                matches = deep_match_session(s, query)
                if matches:
                    results.append(s)
                    deep_matches[s["sessionId"]] = matches

    results = sort_by_date(results)

    # Cap display
    if len(results) > 50:
        print(f"{DIM}Showing top 50 of {len(results)} matches.{RESET}")
        results = results[:50]

    displayed = display_sessions(results, query, deep_matches)
    if displayed:
        selected = select_session(displayed)
        if selected:
            resume_session(selected)


if __name__ == "__main__":
    main()
