;;; vtmux-code.el --- Claude Code workflow via vterm + tmux -*- lexical-binding: t; -*-

;; Author: guxi11
;; Version: 0.3.0
;; Package-Requires: ((emacs "29.1") (vterm "0.0.2") (multi-vterm "1.0") (transient "0.4.0"))
;; Keywords: tools, terminals, ai
;; URL: https://github.com/guxi11/vtmux-code

;;; Commentary:
;; Wraps vterm, tmux and Claude into a unified workflow.
;; One tmux session per git project, one multi-vterm buffer.
;; Sessions persist across Emacs restarts.

;;; Code:

(require 'vterm)
(require 'multi-vterm)
(require 'transient)
(require 'project)

;;; Customization

(defgroup vtmux-code nil
  "Claude Code workflow via vterm + tmux."
  :group 'tools
  :prefix "vtmux-code-")

(defcustom vtmux-code-command nil
  "Command to launch Claude in new panes.
When nil, `vtmux-code-toggle' will prompt you to set it.
Persisted via `customize-save-variable'."
  :type '(choice (const :tag "Not set (will prompt)" nil)
                 (string :tag "Command"))
  :group 'vtmux-code)

(defcustom vtmux-code-window-width 90
  "Width of the vterm side window."
  :type 'integer
  :group 'vtmux-code)

(defcustom vtmux-code-window-side 'right
  "Side to display the vterm window."
  :type '(choice (const right) (const left) (const bottom))
  :group 'vtmux-code)

;;; Internal State

;; project-root -> vterm buffer
(defvar vtmux-code--project-buffers (make-hash-table :test 'equal))

;;; Pure Helpers

(defun vtmux-code--project-root ()
  "Return project root via `project-current', like `multi-vterm-project'."
  (project-root
   (or (project-current) `(transient . ,default-directory))))

(defun vtmux-code--session-name (root)
  "Derive tmux session name from project ROOT."
  (concat "vtmux_" (file-name-nondirectory (directory-file-name root))))

(defun vtmux-code--buffer-name (session)
  "Buffer name for tmux SESSION."
  (format "*%s*" session))

(defun vtmux-code--format-path (filepath root)
  "Format FILEPATH as relative to ROOT if inside, absolute otherwise."
  (let ((expanded (expand-file-name filepath))
        (expanded-root (expand-file-name root)))
    (if (string-prefix-p expanded-root expanded)
        (file-relative-name expanded expanded-root)
      expanded)))

(defun vtmux-code--live-buffer (root)
  "Return live vterm buffer for ROOT, or nil."
  (let ((buf (gethash root vtmux-code--project-buffers)))
    (when (and buf (buffer-live-p buf))
      buf)))

;;; Command Setup

;;;###autoload
(defun vtmux-code-set-command (cmd)
  "Set and persist `vtmux-code-command' to CMD."
  (interactive "sCode command (e.g. claude --enable-auto-mode): ")
  (customize-save-variable 'vtmux-code-command cmd)
  (message "vtmux-code-command set to: %s" cmd))

(defun vtmux-code--ensure-command ()
  "Ensure `vtmux-code-command' is set, prompt if nil.  Return the command."
  (unless vtmux-code-command
    (call-interactively #'vtmux-code-set-command))
  vtmux-code-command)

;;; tmux Interaction

(defun vtmux-code--tmux (&rest args)
  "Run tmux with ARGS, return trimmed stdout."
  (string-trim
   (with-output-to-string
     (apply #'call-process "tmux" nil standard-output nil args))))

(defun vtmux-code--session-exists-p (session)
  "Non-nil if tmux SESSION exists."
  (zerop (call-process "tmux" nil nil nil "has-session" "-t" session)))

(defun vtmux-code--send (session text)
  "Send TEXT to active pane of tmux SESSION."
  (vtmux-code--tmux "send-keys" "-t" session text "Enter"))

;;; Session Management

(defun vtmux-code--create-session (root session)
  "Create vterm buffer attached to tmux SESSION in project ROOT.
Creates tmux session externally first, then vterm attaches to it."
  (let ((existed (vtmux-code--session-exists-p session)))
    ;; Phase 1: ensure tmux session exists (synchronous, no race)
    (unless existed
      (call-process "tmux" nil nil nil
                    "new-session" "-d" "-s" session "-c" root)
      ;; Send claude command now — detached session shell is ready
      (let ((cmd (vtmux-code--ensure-command)))
        (vtmux-code--send session cmd)))
    ;; Phase 2: create vterm and attach
    (let* ((buf-name (vtmux-code--buffer-name session))
           (default-directory root)
           (buf (multi-vterm)))
      (with-current-buffer buf
        (rename-buffer buf-name t)
        (vterm-send-string
         (format "tmux attach -t %s" (shell-quote-argument session)))
        (vterm-send-return))
      (puthash root buf vtmux-code--project-buffers)
      buf)))

(defun vtmux-code--show-buffer (buf)
  "Display BUF in a side window."
  (display-buffer buf
                  `((display-buffer-reuse-window display-buffer-in-direction)
                    (direction . ,vtmux-code-window-side)
                    (window-width . ,vtmux-code-window-width))))

;;; Interactive Commands — Session

;;;###autoload
(defun vtmux-code-toggle ()
  "Toggle Claude tmux session for current project.
Creates session + runs Claude if none exists.
Prompts for `vtmux-code-command' if not set."
  (interactive)
  (let* ((root (vtmux-code--project-root))
         (session (vtmux-code--session-name root))
         (buf (vtmux-code--live-buffer root)))
    (cond
     ;; Buffer visible → hide
     ((and buf (get-buffer-window buf))
      (delete-window (get-buffer-window buf)))
     ;; Buffer exists → show
     (buf
      (vtmux-code--show-buffer buf)
      (select-window (get-buffer-window buf)))
     ;; No buffer → create
     (t
      (let ((new-buf (vtmux-code--create-session root session)))
        (vtmux-code--show-buffer new-buf)
        (select-window (get-buffer-window new-buf)))))))

;;;###autoload
(defun vtmux-code-new-pane (name)
  "Create a new tmux window named NAME with Claude in current project's session."
  (interactive "sPane name: ")
  (let* ((root (vtmux-code--project-root))
         (session (vtmux-code--session-name root))
         (cmd (vtmux-code--ensure-command)))
    (unless (vtmux-code--session-exists-p session)
      (vtmux-code-toggle))
    ;; new-window creates a tmux window (tab), not a split
    (vtmux-code--tmux "new-window" "-t" session "-c" root)
    (unless (string-empty-p name)
      (vtmux-code--tmux "rename-window" "-t" session name))
    (vtmux-code--send session cmd)))

;;;###autoload
(defun vtmux-code-open-shell ()
  "Open a plain shell window at first position in current project's tmux session."
  (interactive)
  (let* ((root (vtmux-code--project-root))
         (session (vtmux-code--session-name root)))
    (unless (vtmux-code--session-exists-p session)
      (vtmux-code-toggle))
    ;; Create new window, then move it to index 0
    (vtmux-code--tmux "new-window" "-t" session "-c" root)
    (vtmux-code--tmux "move-window" "-t" (concat session ":0"))))

;;; Interactive Commands — Send

;;;###autoload
(defun vtmux-code-send-path ()
  "Send @<filepath> of current buffer to the active tmux pane.
Path is relative to project root if inside, absolute otherwise."
  (interactive)
  (let* ((root (vtmux-code--project-root))
         (session (vtmux-code--session-name root))
         (path (vtmux-code--format-path (buffer-file-name) root)))
    (vtmux-code--send session (format "@%s" path))))

;;;###autoload
(defun vtmux-code-send-region ()
  "Send @<filepath>:<start>-<end> of active region to the active tmux pane."
  (interactive)
  (unless (use-region-p)
    (user-error "No active region"))
  (let* ((root (vtmux-code--project-root))
         (session (vtmux-code--session-name root))
         (path (vtmux-code--format-path (buffer-file-name) root))
         (start (line-number-at-pos (region-beginning)))
         (end (line-number-at-pos (region-end))))
    (vtmux-code--send session (format "@%s:%d-%d" path start end))))

;;;###autoload
(defun vtmux-code-send-command (cmd)
  "Send CMD string to the active tmux pane."
  (interactive "sCommand: ")
  (let* ((root (vtmux-code--project-root))
         (session (vtmux-code--session-name root)))
    (vtmux-code--send session cmd)))

;;;###autoload
(defun vtmux-code-send-return ()
  "Send Enter to the active tmux pane."
  (interactive)
  (let* ((root (vtmux-code--project-root))
         (session (vtmux-code--session-name root)))
    (vtmux-code--tmux "send-keys" "-t" session "Enter")))

;;;###autoload
(defun vtmux-code-send-escape ()
  "Send Escape to the active tmux pane."
  (interactive)
  (let* ((root (vtmux-code--project-root))
         (session (vtmux-code--session-name root)))
    (vtmux-code--tmux "send-keys" "-t" session "Escape")))

;;; Interactive Commands — Manage

;;;###autoload
(defun vtmux-code-kill ()
  "Kill tmux session and vterm buffer for current project."
  (interactive)
  (let* ((root (vtmux-code--project-root))
         (session (vtmux-code--session-name root))
         (buf (vtmux-code--live-buffer root)))
    (when (vtmux-code--session-exists-p session)
      (vtmux-code--tmux "kill-session" "-t" session))
    (when buf
      (when (get-buffer-window buf)
        (delete-window (get-buffer-window buf)))
      (kill-buffer buf))
    (remhash root vtmux-code--project-buffers)))

;;; Transient Menu

;;;###autoload (autoload 'vtmux-code-transient "vtmux-code" nil t)
(transient-define-prefix vtmux-code-transient ()
  "vtmux-code commands."
  ["Session"
   ("c" "Toggle Claude session" vtmux-code-toggle)
   ("i" "New Claude pane"       vtmux-code-new-pane)
   ("o" "Open shell pane"       vtmux-code-open-shell)]
  ["Send"
   ("p" "Send file path"  vtmux-code-send-path)
   ("r" "Send region ref" vtmux-code-send-region)
   ("s" "Send command"    vtmux-code-send-command)]
  ["Quick"
   ("y" "Confirm (Enter)"  vtmux-code-send-return)
   ("n" "Reject (Escape)"  vtmux-code-send-escape)]
  ["Manage"
   ("k" "Kill session"  vtmux-code-kill)
   ("=" "Set command"   vtmux-code-set-command)])

;;; Global Minor Mode

(defvar vtmux-code-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c t") #'vtmux-code-transient)
    map)
  "Keymap for `vtmux-code-mode'.")

;;;###autoload
(define-minor-mode vtmux-code-mode
  "Global minor mode for vtmux-code keybindings.
Binds \\`C-c t' to the vtmux-code transient menu."
  :global t
  :lighter " VTX"
  :keymap vtmux-code-mode-map)

(provide 'vtmux-code)
;;; vtmux-code.el ends here
