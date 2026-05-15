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
(vtmux-code-mode 1)  ; binds C-c t
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
- Claude command is prompted on first use, persisted to `~/.emacs.d/vtmux-code-command`

## Configuration

```elisp
;; Window placement
(setq vtmux-code-window-width 90)
(setq vtmux-code-window-side 'right)  ; 'left 'bottom
```

The Claude command is prompted on first use and persisted to `~/.emacs.d/vtmux-code-command`. Change it anytime with `M-x vtmux-code-set-command` or `C-c t m`.

> **Why not customize?** `customize-save-variable` is unreliable for deferred packages — any early `custom-save-all` (e.g. from `package-selected-packages`) rewrites `custom-file` and drops variables whose `defcustom` hasn't evaluated yet.

## Activities.el Integration

When used with [activities.el](https://github.com/alphapapa/activities.el), vtmux vterm buffers are automatically re-attached to their tmux sessions after an activity is resumed (e.g. after Emacs restart). No extra configuration needed — the advice is set up via `with-eval-after-load` and only activates if activities is loaded.

## License

GPL-3.0
