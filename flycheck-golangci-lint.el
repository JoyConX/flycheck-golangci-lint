;;; flycheck-golangci-lint.el --- Flycheck checker for golangci-lint  -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Wei Jian Gan

;; Author: Wei Jian Gan <weijiangan@outlook.com>
;; Keywords: convenience, tools, go
;; Package-Version: 20190330.1412
;; URL: https://github.com/weijiangan/flycheck-golangci-lint
;; Version: 0.1.0
;; Package-Requires: ((emacs "24") (flycheck "0.22"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Flycheck checker for golangci-lint
;;
;; Usage:
;;
;;     (eval-after-load 'flycheck
;;       '(add-hook 'flycheck-mode-hook #'flycheck-golangci-lint-setup))

;;; Code:

(require 'flycheck)

(flycheck-def-option-var flycheck-golangci-lint-config nil golangci-lint
  "Path to golangci-lint configuration file if you don't like using default config path .golangci.(yml|toml|json)"
  :safe #'stringp)

(flycheck-def-option-var flycheck-golangci-lint-deadline "1m" golangci-lint
  "Timeout for running golangci-lint, 1m by default."
  :safe #'stringp)

(flycheck-def-option-var flycheck-golangci-lint-tests nil golangci-lint
  "Analyze *_test.go files. It's false by default."
  :safe #'booleanp
  :type 'boolean)

(flycheck-def-option-var flycheck-golangci-lint-fast nil golangci-lint
  "Run only fast linters from the enabled set of linters. To find out which linters are fast run golangci-lint linters."
  :safe #'booleanp
  :type 'boolean)

(flycheck-def-option-var flycheck-golangci-lint-disable-all nil golangci-lint
  "Disable all linters"
  :safe #'booleanp
  :type 'boolean)

(flycheck-def-option-var flycheck-golangci-lint-enable-all nil golangci-lint
  "Enable all linters"
  :safe #'booleanp
  :type 'boolean)

(flycheck-def-option-var flycheck-golangci-lint-enable-linters nil golangci-lint
  "Enable specific linters"
  :type '(repeat (string :tag "linter"))
  :safe #'flycheck-string-list-p)

(flycheck-def-option-var flycheck-golangci-lint-disable-linters nil golangci-lint
  "Disable specific linters"
  :type '(repeat (string :tag "linter"))
  :safe #'flycheck-string-list-p)



(flycheck-define-checker golangci-build
  "A Go syntax and type checker using the `go build' command.

Requires Go 1.6 or newer.  See URL `https://golang.org/cmd/go'."
  :command ("go" "build"
            (option-flag "-i" flycheck-go-build-install-deps)
            ;; multiple tags are listed as "dev debug ..."
            (option-list "-tags=" flycheck-go-build-tags concat)
            "-o" null-device)
  :error-patterns
  ((error line-start (file-name) ":" line ":"
          (optional column ":") " "
          (message (one-or-more not-newline)
                   (zero-or-more "\n\t" (one-or-more not-newline)))
          line-end)
   ;; Catch error message about multiple packages in a directory, which doesn't
   ;; follow the standard error message format.
   (info line-start
         (message "can't load package: package "
                  (one-or-more (not (any ?: ?\n)))
                  ": found packages "
                  (one-or-more not-newline))
         line-end))
  :error-filter
  (lambda (errors)
    (dolist (error errors)
      (unless (flycheck-error-line error)
        ;; Flycheck ignores errors without line numbers, but the error
        ;; message about multiple packages in a directory doesn't come with a
        ;; line number, so inject a fake one.
        (setf (flycheck-error-line error) 1)))
    errors)
  :modes go-mode
  :predicate (lambda ()
               (and (flycheck-buffer-saved-p)
                    (not (string-suffix-p "_test.go" (buffer-file-name)))))
  )


(flycheck-define-checker golangci-lint
  "A Go syntax checker using golangci-lint that's 5x faster than gometalinter

See URL `https://github.com/golangci/golangci-lint'."
  :command ("golangci-lint" "run" "--print-issued-lines=false" "--out-format=line-number" "--tests=false" "--max-issues-per-linter=10000"  "--max-same-issues=10000"
            (option "--config=" flycheck-golangci-lint-config concat)
            (option "--deadline=" flycheck-golangci-lint-deadline concat)
            ;;(option-flag "--tests" flycheck-golangci-lint-tests)
            (option-flag "--fast" flycheck-golangci-lint-fast)
            (option-flag "--disable-all" flycheck-golangci-lint-disable-all)
            (option-flag "--enable-all" flycheck-golangci-lint-enable-all)
            (option-list "--disable=" flycheck-golangci-lint-disable-linters concat)
            (option-list "--enable=" flycheck-golangci-lint-enable-linters concat)
            ".")
  :error-patterns
  ((warning line-start (file-name) ":" line ":" column ": " (message) line-end)
   (warning line-start (file-name) ":" line ":" (message) line-end))
  :modes go-mode
  :next-checkers ((error . golangci-build))
  )

;;;###autoload
(defun flycheck-golangci-lint-setup ()
  "Setup Flycheck GolangCI-Lint.
Add `golangci-lint' to `flycheck-checkers'."
  (interactive)
  (add-to-list 'flycheck-checkers 'golangci-build)
  (add-to-list 'flycheck-checkers 'golangci-lint)
  )

(provide 'flycheck-golangci-lint)
;;; flycheck-golangci-lint.el ends here
