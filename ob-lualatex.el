;;; ob-lualatex.el --- org-babel support for lualatex evaluation  -*- lexical-binding: t; -*-

;;; Commentary:

;; Org-Babel support for evaluating lualatex source blocks.
;;
;; Why?
;; - The main purpose of this is to inline TikZ images in org files.
;; - I found working with fonts to be much easier with lualatex.
;; - Org seems to support lualatex only when _exporting_ org files.
;;   For my use case, which is using Babel to turn LaTeX/TikZ snippets
;;   into (inline) images via lualatex, I couldn't get stock Org to work.
;;
;; Notes:
;; - The code is mostly copied from https://github.com/arnm/ob-mermaid/
;; - I've had some help from AI, caveat emptor
;;
;; Supported header arguments:
;; :file       - Output PNG file (required)
;; :density    - ImageMagick -density value (optional, default 200)
;; :background - ImageMagick background color (optional, default transparent)

;;; Requirements:

;; lualatex | https://www.tug.org/texlive/
;; magick   | https://imagemagick.org/

;;; Code:
(require 'ob)
(require 'ob-eval)

(defvar org-babel-default-header-args:lualatex
  '((:results . "file") (:exports . "results") (:density . 200))
  "Default arguments for evaluating a lualatex source block.")

(defvar org-src-lang-modes)
(add-to-list 'org-src-lang-modes '("lualatex" . latex))

(defun org-babel-execute:lualatex (body params)
  (let* ((out-file (or (cdr (assoc :file params))
                       (error "lualatex requires a \":file\" header argument")))
         (density (cdr (assoc :density params)))
         (background (cdr (assoc :background params)))
         (temp-dir (make-temp-file "ob-lualatex-" t))
         (tex-file (expand-file-name "input.tex" temp-dir))
         (pdf-file (expand-file-name "input.pdf" temp-dir))
         (lualatex-cmd (concat "lualatex"
                               " -interaction=nonstopmode"
                               " -output-directory=" (shell-quote-argument temp-dir)
                               " " (shell-quote-argument tex-file)))
         (magick-cmd (concat "magick"
                             (when density
                               (concat " -density " (shell-quote-argument
                                                     (if (numberp density)
                                                         (number-to-string density)
                                                       density))))
                             " -background " (shell-quote-argument (or background "transparent"))
                             " " (shell-quote-argument pdf-file)
                             " -flatten"
                             " " (shell-quote-argument out-file))))
    (with-temp-file tex-file (insert body))
    (let ((log-file (expand-file-name "input.log" temp-dir)))
      (unless (eq 0 (call-process-shell-command lualatex-cmd))
        (org-babel-eval-error-notify
         1
         (if (file-readable-p log-file)
             (with-temp-buffer
               (insert-file-contents log-file)
               (buffer-string))
           "(no log file produced)"))
        (error "lualatex failed")))
    (org-babel-eval magick-cmd "")
    nil))

(provide 'ob-lualatex)

;;; ob-lualatex.el ends here
