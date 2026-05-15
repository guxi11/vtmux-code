# vtmux-code vs claude-code.el

Two Emacs packages for working with Claude Code CLI. Different architectures, different trade-offs.

## Architecture

| | claude-code.el | vtmux-code |
|---|---|---|
| Terminal layer | vterm / eat / ghostel (direct) | vterm → tmux |
| Session persistence | No — dies with Emacs | Yes — tmux sessions survive |
| Multi-instance | Hash table per directory | tmux windows per project |
| Buffer management | One buffer per project + named instances | One vterm buffer, multiple tmux windows |
| Lines of code | ~1500 | ~200 |
| Dependencies | Emacs 30+, transient 0.7.5+ | Emacs 29.1+, vterm, multi-vterm, tmux |

## Core Design

**claude-code.el** — Feature-rich terminal wrapper. Abstracts multiple terminal backends behind a generic interface. The package handles everything inside Emacs: buffer routing, hook integration via `emacsclient`, desktop notifications, image pasting, slash command menus, conversation management (resume/fork/read-only).

**vtmux-code** — Thin tmux bridge. Delegates session lifecycle to tmux, Emacs just attaches via vterm. All multi-session logic lives in tmux (windows, panes). The package is a transient menu that sends keys to the right tmux session.

## Feature Comparison

| Feature | claude-code.el | vtmux-code |
|---|---|---|
| Session persistence | No | Yes (tmux) |
| Send file reference | Inline text | `@file` (typed, no Enter) |
| Send region reference | Inline text | `@file:L10-L20` |
| Send selected text | Yes | Yes |
| Quick confirm/reject | Yes (y/n/1/2/3 without switching) | Yes (y/n via tmux send-keys) |
| Multiple Claude instances | Named instances per project | tmux windows per session |
| Shell alongside Claude | Separate | `C-c t o` opens shell at window 0 |
| Image paste | Yes (clipboard → `@path`) | No |
| Hook system | Yes (emacsclient bidirectional) | No |
| Desktop notifications | Yes (macOS/Linux/Windows) | No |
| Slash command menu | Full transient submenu | No (type directly) |
| Conversation resume/fork | Yes | No (tmux scrollback persists) |
| Mode cycling | plan → auto-accept → default | No (type directly) |
| Error fixing (flycheck) | Yes (point at error → fix) | No |
| Window navigation | No | j/k prev/next tmux window |
| Activities.el integration | No | Yes (auto re-attach) |

## When to use which

**vtmux-code** if you:
- Want sessions that survive Emacs restarts / crashes
- Already use tmux
- Prefer minimal code you can read in 10 minutes
- Want a shell window alongside Claude in the same session
- Use activities.el for workspace management

**claude-code.el** if you:
- Want deep Emacs integration (hooks, notifications, image paste)
- Need flycheck/flymake error-to-fix workflow
- Want conversation management (resume, fork, read-only)
- Prefer everything inside Emacs without external dependencies
- Need multiple terminal backend options (eat for pure elisp, ghostel for speed)
