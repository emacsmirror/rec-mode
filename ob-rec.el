;;; ob-rec.el --- org-babel functions for recutils evaluation  -*- lexical-binding: t; -*-

;; Copyright (C) 2011-2021  Free Software Foundation, Inc.

;; Author: Jose E. Marchesi <jemarch@gnu.org>
;; Maintainer: Antoine Kalmbach <ane@iki.fi>
;; Keywords: literate programming, reproducible research
;; Homepage: http://orgmode.org
;; Version: 7.7

;; This file is NOT part of GNU Emacs.

;; This program is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;;; Commentary:

;; Org-Babel support for evaluating recsel queries and substituing the
;; contained template.  See http://www.gnu.org/software/recutils/

;;; Code:
;; (require 'ob)

;; FIXME: `org-babel-trim' was renamed `org-trim' in Org-9.0!
(declare-function org-babel-trim "org-compat" (s &optional keep-lead))

;; FIXME: Presumably `org-babel-execute:rec' will only be called by
;; org-babel, so it's OK to call `org-babel-trim', but what
;; makes us so sure that `org-table' will be loaded by then as well?
(declare-function org-table-convert-region "org-table" (beg0 end0 &optional separator))
(declare-function org-table-to-lisp "org-table" (&optional txt))

(defvar org-babel-default-header-args:rec
  '((:exports . "results")))

(defun org-babel-execute:rec (body params)
  "Execute a block containing a recsel query.
This function is called by `org-babel-execute-src-block'."
  (let* ((in-file (let ((el (cdr (assoc :data params))))
		    (or el
			(error
                         "rec code block requires :data header argument"))))
         (result-params (cdr (assq :result-params params)))
	 ;; (cmdline (cdr (assoc :cmdline params)))
	 (rec-type (cdr (assoc :type params)))
	 (fields (cdr (assoc :fields params)))
         (join (cdr (assoc :join params)))
         (sort (cdr (assoc :sort params)))
         (groupby (cdr (assoc :groupby params)))
         ;; Why not make this a *list* of strings, so we can later just map
         ;; `shell-quote-argument' over all its elements?
         ;; And if `do-raw' is selected we don't even need that because we can
         ;; use `call-process'.
	 (cmd (concat "recsel"
		      (when rec-type (concat " -t " rec-type " "))
		      ;; FIXME: Why `expand-file-name'?
		      ;; FIXME: Shouldn't this need `shell-quote-argument'?
		      " " (expand-file-name in-file)
		      (when (> (length (org-babel-trim body)) 0)
		        ;; FIXME: Shouldn't this use `shell-quote-argument'?
                        (concat " -e " "\""
                                (replace-regexp-in-string "\"" "\\\\\"" body)
                                "\""))
                      (when join (concat " -j " join " "))
                      (when sort (concat " -S " sort " "))
                      (when groupby (concat " -G " groupby " "))
		      (when fields (concat " -p " fields " "))))
         (do-raw (or (member "scalar" result-params)
                     (member "html" result-params)
                     (member "code" result-params)
                     (member "verbatim" result-params)
                     (equal (point-min) (point-max)))))
    (unless do-raw
      ;; Get the csv representation, that will be used by
      ;; org-table-convert-region below.
      (setq cmd (concat cmd " | rec2csv")))
    (with-temp-buffer
      (shell-command cmd (current-buffer))
      (if do-raw
          (buffer-string)
	(org-table-convert-region (point-min) (point-max) '(4))
        (let ((table (org-table-to-lisp)))
          ;; The first row always contains the table header.
          (cons (car table) (cons 'hline (cdr table))))))))

(provide 'ob-rec)

;; ob-rec.el ends here
