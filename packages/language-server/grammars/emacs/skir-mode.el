;;; skir-mode.el --- Major mode for Skir schema files  -*- lexical-binding: t; -*-

;; Author: Tyler Fibonacci
;; Homepage: https://skir.build
;; Keywords: languages skir
;; Version: 0.1.0

;;; Commentary:
;; Provides syntax highlighting and basic editing support for .skir files.
;; Pairs with skir-language-server for diagnostics, completion, and more.
;;
;; To connect to skir-language-server via Eglot (Emacs 29+ built-in):
;;
;;   (with-eval-after-load 'eglot
;;     (add-to-list 'eglot-server-programs
;;                  '(skir-mode . ("skir-language-server" "--stdio"))))
;;
;; Or via lsp-mode:
;;
;;   (with-eval-after-load 'lsp-mode
;;     (add-to-list 'lsp-language-id-configuration '(skir-mode . "skir"))
;;     (lsp-register-client
;;      (make-lsp-client
;;       :new-connection (lsp-stdio-connection '("skir-language-server" "--stdio"))
;;       :major-modes '(skir-mode)
;;       :server-id 'skir-ls)))

;;; Code:

(defconst skir-mode--keywords
  '("struct" "enum" "const" "method" "import" "from" "as" "removed"))

(defconst skir-mode--builtin-types
  '("bool" "int32" "int64" "hash64" "float32" "float64" "string" "bytes" "timestamp"))

(defconst skir-mode--constants
  '("true" "false" "null"))

(defvar skir-mode-font-lock-keywords
  `(;; Keywords
    (,(regexp-opt skir-mode--keywords 'words) . font-lock-keyword-face)
    ;; Built-in types
    (,(regexp-opt skir-mode--builtin-types 'words) . font-lock-type-face)
    ;; Language constants
    (,(regexp-opt skir-mode--constants 'words) . font-lock-constant-face)
    ;; CamelCase identifiers are type names (listed first so ALL_CAPS can override)
    ("\\b[A-Z][A-Za-z0-9_]*\\b" . font-lock-type-face)
    ;; ALL_CAPS identifiers are constants (listed last so it wins over CamelCase rule)
    ("\\b[A-Z][A-Z0-9_]+\\b" . font-lock-constant-face)))
    ;; Numbers
    ("\\b-?[0-9]+\\(\\.[0-9]+\\)?\\([eE][+-]?[0-9]+\\)?\\b" . font-lock-constant-face)))

(defvar skir-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; // line comments and /* */ block comments
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)
    ;; String delimiters
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?' "\"" table)
    ;; Braces and brackets
    (modify-syntax-entry ?{ "(}" table)
    (modify-syntax-entry ?} "){" table)
    (modify-syntax-entry ?[ "(]" table)
    (modify-syntax-entry ?] ")[" table)
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    table)
  "Syntax table for `skir-mode'.")

;;;###autoload
(define-derived-mode skir-mode prog-mode "Skir"
  "Major mode for editing Skir schema files."
  :syntax-table skir-mode-syntax-table
  (setq-local font-lock-defaults '(skir-mode-font-lock-keywords))
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "\\(//+\\|/\\*+\\)\\s *"))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.skir\\'" . skir-mode))

(provide 'skir-mode)
;;; skir-mode.el ends here
