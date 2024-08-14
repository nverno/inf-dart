;;; inf-dart.el --- Run a Dart repl in an inferior process -*- lexical-binding: t; -*-

;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/inf-dart
;; Version: 0.0.1
;; Package-Requires: ((emacs "29.1") (dart-ts-mode "0"))
;; Created: 13 August 2024
;; Keywords: dart languages repl

;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;; Code:

(require 'dart-ts-mode)                 ; syntax-table
(require 'comint)

(defgroup inf-dart nil
  "Run Dart process in a buffer."
  :group 'languages
  :prefix "inf-dart-")

(defcustom inf-dart-command "~/.pub-cache/bin/interactive"
  "Command to run inferior Dart process."
  :type 'string
  :risky t)

(defcustom inf-dart-arguments '("-i")
  "Command line arguments for `inf-dart-command'."
  :type '(repeat string))

(defcustom inf-dart-buffer-name "Dart"
  "Default buffer name for the Dart interpreter."
  :type 'string
  :safe 'stringp)

(defcustom inf-dart-prompt "> "
  "Regexp matching the top-level prompt used by the inferior Dart process."
  :type 'regexp
  :safe 'stringp)

(defcustom inf-dart-prompt-continue ">> "
  "Regexp matching the continuation prompt used by the inferior Dart process."
  :type 'regexp
  :safe 'stringp)

(defcustom inf-dart-history-filename nil
  "File used to save command history of the inferior Dart process."
  :type '(choice (const :tag "None" nil) file)
  :safe 'string-or-null-p)

(defcustom inf-dart-startfile nil
  "File to load into the inferior Dart process at startup."
  :type '(choice (const :tag "None" nil) (file :must-match t)))


(defun inf-dart-calculate-command (&optional prompt default)
  "Calculate command to start repl.
If PROMPT is non-nil, read command interactively using DEFAULT if non-nil."
  (unless default
    (setq default (concat inf-dart-command " "
                          (mapconcat 'identity inf-dart-arguments " "))))
  (if prompt (read-shell-command "Run Dart: " default) default))

(defun inf-dart-buffer ()
  "Return inferior Dart buffer for current buffer."
  (if (derived-mode-p 'inf-dart-mode)
      (current-buffer)
    (let* ((proc-name inf-dart-buffer-name)
           (buffer-name (format "*%s*" proc-name)))
      (when (comint-check-proc buffer-name)
        buffer-name))))

(defun inf-dart-process ()
  "Return inferior Dart process for current buffer."
  (get-buffer-process (inf-dart-buffer)))

;;;###autoload
(defun inf-dart-run (&optional prompt cmd startfile show)
  "Run a Dart interpreter in an inferior process.
With prefix, PROMPT, read command.
If CMD is non-nil, use it to start repl.
STARTFILE overrides `inf-dart-startfile' when present.
When called interactively, or with SHOW, show the repl buffer after starting."
  (interactive (list current-prefix-arg nil nil t))
  (let* ((cmd (inf-dart-calculate-command prompt cmd))
         (buffer (inf-dart-make-comint
                  cmd
                  inf-dart-buffer-name
                  (or startfile inf-dart-startfile)
                  show)))
    (get-buffer-process buffer)))

(defun inf-dart-make-comint (cmd proc-name &optional startfile show)
  "Create a Dart comint buffer.
CMD is the Dart command to be executed and PROC-NAME is the process name
that will be given to the comint buffer.
If STARTFILE is non-nil, use that instead of `inf-dart-startfile'
which is used by default. See `make-comint' for details of STARTFILE.
If SHOW is non-nil, display the Dart comint buffer after it is created.
Returns the name of the created comint buffer."
  (let ((proc-buff-name (format "*%s*" proc-name)))
    (unless (comint-check-proc proc-buff-name)
      (let* ((cmdlist (split-string-and-unquote cmd))
             (program (car cmdlist))
             (args (cdr cmdlist))
             (buffer (apply #'make-comint-in-buffer proc-name
                            proc-buff-name
                            program
                            startfile
                            args)))
        ;; (set-process-sentinel
        ;;  (get-buffer-process buffer) #'inf-dart--write-history)
        (with-current-buffer buffer
          (inf-dart-mode))))
    (when show
      (pop-to-buffer proc-buff-name))
    proc-buff-name))


(defvar-keymap inf-dart-mode-map
  :doc "Keymap in inferior Dart buffer."
  ;; "TAB" #'completion-at-point
  )

;;;###autoload
(define-derived-mode inf-dart-mode comint-mode "Dart"
  "Major mode for Dart repl.

\\<inf-dart-mode-map>"
  :syntax-table dart-ts-mode--syntax-table
  (setq-local mode-line-process '(":%s")
              comment-start "//"
              comment-end ""
              comment-start-skip "//+ *"
              parse-sexp-ignore-comments t
              parse-sexp-lookup-properties t)
  ;; (inf-dart--calculate-prompt-regexps)
  (setq-local comint-input-ignoredups t
              comint-input-ring-file-name inf-dart-history-filename
              comint-prompt-read-only t
              comint-prompt-regexp inf-dart-prompt
              comint-output-filter-functions '(ansi-color-process-output)
              comint-highlight-input nil)
  ;; (add-hook 'comint-preoutput-filter-functions #'inf-dart--preoutput-filter nil t)
  (setq-local scroll-conservatively 1)

  ;; Font-locking
  ;; (setq-local font-lock-defaults '(inf-dart-font-lock-keywords nil nil))
  (setq comint-indirect-setup-function
        (lambda ()
          (let ((inhibit-message t)
                (message-log-max nil))
            (cond ((fboundp 'dart-ts-mode) (dart-ts-mode))
                  ((fboundp 'dart-mode) (dart-mode))
                  (t nil)))))
  (when (and (null comint-use-prompt-regexp)
             (or (require 'dart-ts-mode nil t)
                 (require 'dart-mode nil t)))
    (comint-fontify-input-mode)))
;; Compilation
;; (setq-local compilation-error-regexp-alist inf-dart-repl-compilation-regexp-alist)
;; (compilation-shell-minor-mode t)
;; (add-hook 'completion-at-point-functions #'inf-dart-completion-at-point nil t)
  
(provide 'inf-dart)
;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
;;; inf-dart.el ends here
