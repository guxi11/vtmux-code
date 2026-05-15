# vtmux-code

Emacs ↔ tmux ↔ Claude Code bridge. One tmux session per project, one vterm buffer. Sessions survive Emacs restarts.

## Install

Requires `tmux` in PATH.

```elisp
(use-package vterm :ensure t)
(use-package multi-vterm :ensure t)

(add-to-list 'load-path "/path/to/vtmux-code")
(require 'vtmux-code)
(vtmux-code-mode 1)  ; binds C-c t
```

## Usage

`C-c t` opens the transient menu:

```
Session
  t  Toggle Claude session
  i  New Claude pane (named)
  o  Open shell pane (first position)
  j  Prev window
  k  Next window

Send
  p  Send @filepath to active pane
  r  Send @filepath:start-end (region)
  t  Send selected text
  s  Send arbitrary command

Quick
  y  Confirm (Enter)
  n  Reject (Escape)

Manage
  x  Kill pane
  K  Kill session
  m  Modify command
```

## How it works

```
C-c t t  →  multi-vterm buffer  →  tmux new-session -s vtmux:<project>
C-c t i  →  tmux new-window     →  runs claude command in new window
C-c t p  →  tmux send-keys "@filepath" (types without Enter)
```

- Project root detected via `locate-dominating-file` (.git), falls back to `default-directory`
- File paths are relative inside project, absolute outside
- Claude command is prompted on first use, persisted to `~/.emacs.d/vtmux-code-command`

## Configuration

```elisp
(setq vtmux-code-window-width 90)
(setq vtmux-code-window-side 'right)        ; 'left 'bottom
(setq vtmux-code-use-side-window t)         ; nil for display-buffer-in-direction
```

Change the Claude command anytime with `C-c t m` or `M-x vtmux-code-set-command`.

## Activities.el Integration

When used with [activities.el](https://github.com/alphapapa/activities.el), vtmux vterm buffers are automatically re-attached to their tmux sessions after an activity is resumed. No extra configuration needed.

## License

GPL-3.0
