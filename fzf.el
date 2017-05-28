;;; fzf.el --- A front-end for fzf.
;;
;; Copyright (C) 2015 by Bailey Ling
;; Author: Bailey Ling
;; URL: https://github.com/bling/fzf.el
;; Filename: fzf.el
;; Description: A front-end for fzf
;; Created: 2015-09-18
;; Version: 0.0.2
;; Package-Requires: ((emacs "24.4"))
;; Keywords: fzf fuzzy search
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING. If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Install:
;;
;; Autoloads will be set up automatically if you use package.el.
;;
;; Usage:
;;
;; M-x fzf
;; M-x fzf-directory
;;
;;; Code:

(defgroup fzf nil
  "Configuration options for fzf.el"
  :group 'convenience)

(defcustom fzf/window-height 15
  "The window height of the fzf buffer"
  :type 'integer
  :group 'fzf)

(defcustom fzf/executable "fzf"
  "The path to the fzf executable."
  :type 'string
  :group 'fzf)

(defcustom fzf/args "-x --color bw --margin 1,0"
  "Additional arguments to pass into fzf."
  :type 'string
  :group 'fzf)

(defcustom fzf/position-bottom t
  "Set the position of the fzf window. Set to nil to position on top."
  :type 'bool
  :group 'fzf)

(defun fzf/default-directory()
  (condition-case err
      (projectile-project-root)
    (error
     default-directory)))

(defun fzf/cmd (cmd)
  (format "stdout=$(%s%s %s %s); echo; echo $stdout"
          (if cmd (concat cmd " | ") "")
          fzf/executable
          (format "--bind \"::execute(grep -Hno ^. {} | cut -f-2 -d: | %s %s)+abort\""
                   fzf/executable
                   fzf/args)
          fzf/args))

(defun fzf/after-term-handle-exit (process-name msg)
  (let* ((text (buffer-substring-no-properties (point-min) (point-max)))
         (lines (split-string text "\n" t nil))
         (line (car (last (butlast lines 1))))
         (selected (split-string line ":"))
         (file (expand-file-name (pop selected)))
         (linenumber (pop selected)))
    (kill-buffer "*fzf*")
    (jump-to-register :fzf-windows)
    (when (file-exists-p file)
      (find-file file)
      (when linenumber
        (goto-char (point-min))
        (forward-line (- (string-to-number linenumber) 1))
        (back-to-indentation))))
  (advice-remove 'term-handle-exit #'fzf/after-term-handle-exit))

(defun fzf/start (directory cmd)
  (require 'term)
  (window-configuration-to-register :fzf-windows)
  (advice-add 'term-handle-exit :after #'fzf/after-term-handle-exit)
  (let ((buf (get-buffer-create "*fzf*"))
        (window-height (if fzf/position-bottom (- fzf/window-height) fzf/window-height)))
    (with-current-buffer buf
      (setq default-directory directory))
    (split-window-vertically window-height)
    (when fzf/position-bottom (other-window 1))
    (make-term "fzf" "sh" nil "-c" (fzf/cmd cmd))
    (switch-to-buffer buf)
    (linum-mode 0)
    (set-window-margins nil 1)

    ;; disable various settings known to cause artifacts, see #1 for more details
    (setq-local scroll-margin 0)
    (setq-local scroll-conservatively 0)
    (setq-local term-suppress-hard-newline t) ;for paths wider than the window
    (face-remap-add-relative 'mode-line '(:box nil))

    (term-char-mode)
    (setq mode-line-format (format "   FZF  %s" directory))))

;;;###autoload
(defun fzf ()
  "Starts a fzf session."
  (interactive)
    (fzf/start (fzf/default-directory) nil))

;;;###autoload
(defun fzf-directory (directory)
  "Starts a fzf session at the specified directory."
  (interactive "D")
  (fzf/start directory nil))

;;;###autoload
(defun fzf-git-grep ()
  "Starts a fzf session based on git grep result"
  (interactive)
  (fzf/start (fzf/default-directory)
              (format "git grep -i --line-number %s -- './*' '!vendor/' '!node_modules/'"
                      (if (region-active-p)
                          (buffer-substring-no-properties (region-beginning) (region-end))
                        (call-interactively (lambda (input) (interactive "sgit grep: ") input))))))

(provide 'fzf)
;;; fzf.el ends here
