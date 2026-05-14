# vtmux-code

Emacs ↔ tmux ↔ Claude Code bridge. One tmux session per project, one vterm buffer. Sessions survive Emacs restarts.

## Why not claude-code.el?

`claude-code.el` talks directly to vterm/eat — sessions die with Emacs, no multi-pane support.

`vtmux-code` uses tmux as the multiplexer: persistent sessions, named panes, and one vterm buffer per project.

| | claude-code.el | vtmux-code |
|---|---|---|
| Terminal layer | vterm/eat/ghostel | vterm → tmux |
| Session persistence | ✗ | ✓ |
| Multi-pane | One buffer per instance | tmux panes |
| Region format | Inline text | `@file:L10-L20` |
| Lines of code | ~1500 | ~200 |

## Install

Requires `tmux` in PATH.

```elisp
;; Dependencies
(use-package vterm :ensure t)
(use-package multi-vterm :ensure t)

;; vtmux-code
(add-to-list 'load-path "/path/to/vtmux-code")
(require 'vtmux-code)
(vtmux-code-setup-keys)  ; binds C-c t
```

## Usage

`C-c t` opens the transient menu:

```
Session
  c  Toggle Claude session
  i  New Claude pane (named)
  o  Open shell pane (first position)

Send
  p  Send @filepath to active pane
  r  Send @filepath:start-end (region)
  s  Send arbitrary command

Quick
  y  Confirm (Enter)
  n  Reject (Escape)

Manage
  k  Kill session
```

## How it works

```
C-c t c  →  multi-vterm buffer  →  tmux new-session -s vtmux:<project>
C-c t i  →  tmux split-window   →  runs claude command in new pane
C-c t p  →  tmux send-keys "@filepath" Enter
```

- Project root detected via `vc-git-root`, falls back to `default-directory`
- File paths are relative inside project, absolute outside
- Claude command is customizable and persists via `M-x customize`

## Configuration

```elisp
;; Set your claude command (persists in custom-file)
(setq vtmux-code-command "claude --enable-auto-mode")

;; Window placement
(setq vtmux-code-window-width 90)
(setq vtmux-code-window-side 'right)  ; 'left 'bottom
```

Or use `M-x customize-group RET vtmux-code`.

## License

GPL-3.0
