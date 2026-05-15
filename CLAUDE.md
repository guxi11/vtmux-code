# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Single-file Emacs Lisp package (`vtmux-code.el`, ~470 lines) — a thin bridge from Emacs to `tmux` for running the Claude Code CLI. One tmux session per git project, one vterm buffer per session. Sessions outlive Emacs because the lifecycle lives in tmux, not Emacs.

This is a git submodule of `guxi11-emacs`. README.md and COMPARISON.md (vs. `claude-code.el`) are the user-facing docs; read them for product context.

## Dev commands

```bash
# Byte-compile (catches most errors; run from this dir)
emacs -Q --batch -L . -f batch-byte-compile vtmux-code.el

# Smoke load
emacs -Q --batch -L . --eval "(require 'vtmux-code)"

# Manual interactive test
open -a /Applications/Emacs.app --args -Q -L $(pwd) --eval "(require 'vtmux-code)" --eval "(vtmux-code-mode 1)"
```

There are no automated tests. Verify changes by exercising the transient menu (`C-c t`) against a real tmux + Claude install.

## Architecture

### Three layers, strictly delegated

```
Emacs (transient menu) → tmux (sessions/windows) → Claude CLI (in panes)
```

- **Emacs owns**: the transient UI, project-root detection, formatting `@file:L10-L20` strings, choosing where to display the vterm window.
- **tmux owns**: session lifecycle, multi-window/pane state, scrollback. Everything multi-instance is tmux windows, never Emacs buffers.
- **vterm** is dumb glue — it just `tmux attach`es to the session created out-of-band via `call-process`.

This split is the whole point. Don't move tmux's responsibilities into Emacs (e.g. don't track windows/panes in elisp state) — that defeats the persistence model. Compare with `claude-code.el` in COMPARISON.md, which makes the opposite choice.

### Session creation is a two-phase dance (`vtmux-code--create-session`)

1. Synchronous `tmux new-session -d` so the session exists before vterm starts (avoids a race where vterm attaches to a not-yet-existing session).
2. `multi-vterm` wrapped in `save-window-excursion` because it calls `switch-to-buffer` internally — we suppress that so `vtmux-code--show-buffer` controls placement.
3. Vterm then sends `tmux attach -t <session>` as its first command.

If you touch this flow, preserve both: the pre-creation of the tmux session, and the window-excursion guard.

### State model

- `vtmux-code--project-buffers` — hash, project-root → vterm buffer. Authoritative cache.
- `vtmux-code--root` — buffer-local on each vterm buffer. Lets sending commands work from inside vterm itself, and lets the activities hook re-bind state after restore.
- `vtmux-code--live-buffer` — falls back to buffer-name lookup if the hash is stale (e.g. after Emacs restart, before any user action repopulates it).
- The "visible session" helpers (`vtmux-code--visible-vterm-window` etc.) deliberately decouple Send commands from the current buffer's project — you send to whatever vtmux pane is on screen, regardless of which file buffer you're in. This is intentional UX; don't "fix" it to use `vtmux-code--project-root` on send.

### Command persistence

`vtmux-code-command` is **not** persisted via `customize-save-all` — it goes to its own file (`vtmux-code--command-file`, default `~/.emacs.d/vtmux-code-command`) loaded on package load. The comment on the defcustom explains why: customize-save-all can clobber a deferred defcustom. Keep this two-track storage.

### Activities.el integration

`activities.el` restores vterm via its bookmark handler, which gives a fresh shell but **drops** the `vtmux-code--root` buffer-local and the tmux attach. `vtmux-code--reattach-after-resume` is advice on `activities-resume` / `activities-set` / `activities-tabs--switch` that, on a 0.5s timer, finds `*vtmux_*` buffers missing `vtmux-code--root`, restores it, and re-issues `tmux attach`. Two things matter if you edit this:

- The 0.5s delay is to let activities finish its own buffer-restore pass.
- The buffer-name regex `\\`\\*\\(vtmux_\\(.+\\)\\)\\*\\'` must match `vtmux-code--buffer-name` output — they're coupled.

### Send-keys vs type

- `vtmux-code--send` — `send-keys ... Enter` — for shell commands.
- `vtmux-code--type` — `send-keys -l` (literal, no Enter) — for `@file` references the user may want to edit before submitting. Don't conflate these.

## Conventions in this file

- Functions are grouped by `;;; Section` headers; preserve them.
- Private helpers use `vtmux-code--` (double dash), public commands use `vtmux-code-` (single dash) and carry `;;;###autoload`.
- Pure helpers (`vtmux-code--format-path`, `--session-name`, `--buffer-name`) take their inputs explicitly — they don't read globals. Keep new helpers in this style; side-effecting tmux/buffer code stays in the "Interactive Commands" sections.
