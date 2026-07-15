;;; init.el --- 最小・実用の Emacs 設定 (育てる用の土台) -*- lexical-binding: t; -*-
;;
;; evil (Vim キー) + which-key + Magit + org-mode の最小構成。ここに足して育てる。

;;; ---------------------------------------------------------------------------
;;; 基本の見た目・挙動
;;; ---------------------------------------------------------------------------
(setq inhibit-startup-message t)
(menu-bar-mode -1)
(setq ring-bell-function 'ignore)
(global-display-line-numbers-mode 1)
(column-number-mode 1)
(show-paren-mode 1)
(setq-default indent-tabs-mode nil)
(setq use-short-answers t)

;; バックアップ・自動保存を1箇所にまとめ、作業ディレクトリを汚さない
(setq backup-directory-alist `(("." . ,(expand-file-name "backups" user-emacs-directory))))
(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-save/" user-emacs-directory) t)))
(make-directory (expand-file-name "auto-save/" user-emacs-directory) t)
(setq create-lockfiles nil)

;; custom-set-variables を init.el に書かせず別ファイルへ
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file) (load custom-file))

;;; ---------------------------------------------------------------------------
;;; パッケージ管理 (package.el + use-package)
;;; ---------------------------------------------------------------------------
(require 'package)
(setq package-archives
      '(("gnu"   . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)

;;; ---------------------------------------------------------------------------
;;; which-key : 押しかけのキーの続きを画面下に一覧表示
;;; ---------------------------------------------------------------------------
(use-package which-key
  :config
  (which-key-mode 1)
  (setq which-key-idle-delay 0.5))

;;; ---------------------------------------------------------------------------
;;; evil : Vim キー操作
;;; ---------------------------------------------------------------------------
(use-package evil
  :init
  (setq evil-want-keybinding nil)         ; evil-collection と併用するため必須
  (setq evil-want-C-u-scroll t)
  (setq evil-undo-system 'undo-redo)
  :config
  (evil-mode 1))

(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))

;;; ---------------------------------------------------------------------------
;;; Magit
;;; ---------------------------------------------------------------------------
(use-package magit
  :commands (magit-status))

;;; ---------------------------------------------------------------------------
;;; org-mode
;;; ---------------------------------------------------------------------------
(use-package org
  :ensure nil                             ; Emacs 同梱
  :config
  (setq org-startup-indented t)
  (setq org-hide-emphasis-markers t)
  (setq org-directory "~/org")
  (setq org-agenda-files '("~/org"))
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (shell . t)
     (python . t)))
  (setq org-confirm-babel-evaluate nil))

;;; ---------------------------------------------------------------------------
;;; leader キー (SPC)
;;; ---------------------------------------------------------------------------
(with-eval-after-load 'evil
  (define-key evil-normal-state-map (kbd "SPC") nil)
  (define-key evil-normal-state-map (kbd "SPC f f") #'find-file)
  (define-key evil-normal-state-map (kbd "SPC f s") #'save-buffer)
  (define-key evil-normal-state-map (kbd "SPC b b") #'switch-to-buffer)
  (define-key evil-normal-state-map (kbd "SPC g s") #'magit-status)
  (define-key evil-normal-state-map (kbd "SPC o a") #'org-agenda)
  (define-key evil-normal-state-map (kbd "SPC h k") #'describe-key)
  (define-key evil-normal-state-map (kbd "SPC h f") #'describe-function))

;;; init.el ends here
