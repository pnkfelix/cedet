;;; chart.el - Draw charts (bar charts, etc)
;;;
;;; Copyright (C) 1996 Eric M. Ludlam
;;;
;;; Author: <zappo@gnu.ai.mit.edu>
;;; Version: 0.1
;;; RCS: $Id: chart.el,v 1.2 1996-10-12 10:22:30 zappo Exp $
;;; Keywords: OO, chart, graph                                           
;;;                                                                          
;;; This program is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2, or (at your option)
;;; any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, you can either send email to this
;;; program's author (see below) or write to:
;;;
;;;              The Free Software Foundation, Inc.
;;;              675 Mass Ave.
;;;              Cambridge, MA 02139, USA. 
;;;
;;; Please send bug reports, etc. to zappo@gnu.ai.mit.edu.
;;;
;;; Future versions of Chart can be found at:
;;;  ftp://ftp.ultranet.com/pub/zappo
;;;
;;; Commentary:
;;;   This package is an experiment of mine aiding in the debugging of
;;; eieio, and proved to be neat enough that others may like to use
;;; it.  To quickly see what you can do with chart, run the command
;;; `chart-test-it-all'.
;;;   Chart current can display bar-charts in either of two
;;; directions.  It also supports ranged (integer) axis, and axis
;;; defined by some set of strings or names.  These name can be
;;; automatically derived from data sequences, which are just lists of
;;; anything encapsulated in a nice eieio object.
;;;   Current example apps for chart can be accessed via these commands:
;;; `chart-file-count'     - count files w/ matching extensions
;;; `chart-space-usage'    - display space used by files/directories
;;; `chart-emacs-storage'  - emacs storage units used/free (garbage-collect)
;;; `chart-emacs-lists'    - length of emacs lists
;;; `chart-rmail-from'     - who sends you the most mail (in -summary only)
;;;
;;; Customization:
;;;   If you find the default colors and pixmaps unpleasant, or too
;;; short, you can change them.  The variable `chart-face-color-list'
;;; contains a list of colors, and `chart-face-pixmap-list' contains
;;; all the pixmaps to use.  The current pixmaps are those found on
;;; several systems I found.  The two lists should be the same length,
;;; as the long list will just be truncated.
;;;   If you would like to draw your own stipples, simply create some
;;; xbm's and put them in a directory, then you can add:
;;;
;;; (setq x-bitmap-file-path (cons "~/mybitmaps" x-bitmap-file-path))
;;;
;;; to your .emacs (or wherever) and load the `chart-face-pixmap-list'
;;; with all the bitmaps you want to use.
;;;
;;; PREFERRED: emacs 19.30 or better, but should work with earlier
;;;            versions but without special fonts/colors/pixmaps

(require 'eieio)

;;;
;;; Variable definitions
;;;
(defvar chart-map nil "Keymap used in chart mode.")
(if chart-map
    ()
  (setq chart-map (make-sparse-keymap))
  )

(defvar chart-local-object nil
  "Local variable containing the locally displayed chart object")
(make-variable-buffer-local 'chart-local-object)

(defvar chart-face-list nil
  "Faces used to colorize charts.  List is limited currently, which is ok
since you really can't display too much in text characters anyways.")
(defvar chart-face-color-list '("red" "green" "blue" 
				"orange" "yellow" "purple")
  "Colors to use when generating chart-face-list.  Colors will be the
background color.")
(defvar chart-face-pixmap-list '("dimple1" "scales" "dot" 
				 "cross_weave" "boxes" "dimple3")
  "If pixmaps are allowed, display these background pixmaps.  Useful
if new emacs is used on B&W display")

(if (not chart-face-list)
    (let ((cl chart-face-color-list)
	  (pl chart-face-pixmap-list)
	  nf)
      (while (and cl pl)
	(setq nf (make-face (intern (concat "chart-" (car cl) "-" (car pl)))))
	(if (> (x-display-color-cells) 4)
	    (set-face-background nf (car cl))
	  (set-face-background nf "white"))
	(set-face-foreground nf "black")
	(if (fboundp 'set-face-background-pixmap)
	    (condition-case nil
		(set-face-background-pixmap nf (car pl))
	      (error (message "Cannot set background pixmap %s" (car pl)))))
	(setq chart-face-list (cons nf chart-face-list))
	(setq cl (cdr cl)
	      pl (cdr pl)))))

(defun chart-mode ()
  "Define a mode in emacs for displaying a chart."
  (kill-all-local-variables)
  (use-local-map chart-map)
  (setq major-mode 'chart-mode
	mode-name "CHART")
  (run-hooks 'chart-mode-hook)
  )

(defun chart-new-buffer (obj)
  "Create a new buffer called NAME in which we will display some tree
type things.  Returns the newly created buffer"
  (save-excursion
    (set-buffer (get-buffer-create (format "*%s*" (oref obj title))))
    (chart-mode)
    (setq chart-local-object obj)
    (current-buffer)))

(defclass chart ()
  ((title :initarg :title
	  :initform "Emacs Chart")
   (title-face :initarg :title-face
	       :initform 'bold-italic)
   (x-axis :initarg :x-axis)
   (x-margin :initarg :x-margin
	     :initform 5)
   (x-width :initarg :x-width
	    :initform (lambda () (- (window-width) 10)))
   (y-axis :initarg :y-axis)
   (y-margin :initarg :y-margin
	     :initform 5)
   (y-width :initarg :y-width
	    :initform (lambda () (- (window-height) 10)))
   (key-label :initarg :key-label
	      :initarg "Key")
   (sequences :initarg :sequences)
   )
  "Superclass for all charts to be displayed in an emacs buffer")

(defclass chart-axis ()
  ((name :initarg :name
	 :initform "Generic Axis")
   (loweredge :initarg :loweredge
	      :initform t)
   (name-face :initarg :name-face
	      :initform 'bold)
   (labels-face :initarg :lables-face
		:initform 'italic)
   (chart :initarg :chart
	  :initform nil)
   )
  "Superclass used for display of an axis.")

(defclass chart-axis-range (chart-axis)
  ((bounds :initarg :bounds
	   :initform (0.0 . 50.0))
   )
  "Class used to display an axis defined by a range of values")

(defclass chart-axis-names (chart-axis)
  ((items :initarg :items
	  :initform nil)
   )
  "Class used to display an axis which represents different named items")

(defclass chart-sequece ()
  ((data :initarg :data
	 :initform nil)
   (name :initarg :name
	 :initform "Data")
   )
  "Class used for all data in different charts")

(defclass chart-bar (chart)
  ((direction :initarg :direction
	      :initform vertical))
  "Subclass for bar charts. (Vertical or horizontal)")

(defmethod chart-draw ((c chart) &optional buff)
  "Start drawing a chart object C in optional BUFF. Erases current contents
of buffer"
  (save-excursion
    (if buff (set-buffer buff))
    (erase-buffer)
    (insert (make-string 100 ?\n))
    ;; Start by displaying the axis
    (chart-draw-axis c)
    ;; Display title
    (chart-draw-title c)
    ;; Display data
    (message "Rendering chart...")
    (sit-for 0)
    (chart-draw-data c)
    ;; Display key
    ; (chart-draw-key c)
    (message "Rendering chart...done")
    ))

(defmethod chart-draw-title ((c chart))
  "Draw a title upon the chart"
  (chart-display-label (oref c title) 'horizontal 0 0 (window-width)
		       (oref c title-face)))

(defmethod chart-size-in-dir ((c chart) dir)
  "Return the physical size of chart C in direction DIR"
  (if (eq dir 'vertical)
      (oref c y-width)
    (oref c x-width)))

(defmethod chart-draw-axis ((c chart))
  "Draw axis into the current buffer defined by chart C"
  (let ((ymarg (oref c y-margin))
	(xmarg (oref c x-margin))
	(ylen (oref c y-width))
	(xlen (oref c x-width)))
    (chart-axis-draw (oref c y-axis) 'vertical ymarg 
		     (if (oref (oref c y-axis) loweredge) nil xlen)
		     xmarg (+ xmarg ylen))
    (chart-axis-draw (oref c x-axis) 'horizontal xmarg 
		     (if (oref (oref c x-axis) loweredge) nil ylen)
		     ymarg (+ ymarg xlen)))
  )

(defmethod chart-axis-draw ((a chart-axis) &optional dir margin zone start end)
  "Draw some axis for A in direction DIR at with MARGIN in 
boundry START -> END"
  (chart-draw-line dir (+ margin (if zone zone 0)) start end)
  (chart-display-label (oref a name) dir (if zone (+ zone margin 3) 
					   (if (eq dir 'horizontal) 
					       1 0))
		       start end (oref a name-face)))

(defmethod chart-translate-xpos ((c chart) x)
  "Translate in chart C the coordinate X into a screen column"
  (let ((range (oref (oref c x-axis) bounds)))
    (+ (oref c x-margin)
       (round (* (float (- x (car range))) 
		 (/ (float (oref c x-width)) 
		    (float (- (cdr range) (car range))))))))
  )

(defmethod chart-translate-ypos ((c chart) y)
  "Translate in chart C the coordinate Y into a screen row"
  (let ((range (oref (oref c y-axis) bounds)))
    (+ (oref c x-margin)
       (- (oref c y-width) 
	  (round (* (float (- y (car range))) 
		    (/ (float (oref c y-width)) 
		       (float (- (cdr range) (car range)))))))))
  )

(defmethod chart-axis-draw ((a chart-axis-range) &optional dir margin zone start end)
  "Draw axis information based upon a range to be spread along the edge"
  (call-next-method)
  ;; We prefer about 5 spaces between each value
  (let* ((i (car (oref a bounds)))
	 (e (cdr (oref a bounds)))
	 (z (if zone zone 0))
	 (s nil)
	 (rng (- e i))
	 ;; want to jump by units of 5 spaces or so
	 (j (/ rng (/  (chart-size-in-dir (oref a chart) dir) 4)))
	 p1)
    (while (<= i e)
      (setq s
	    (cond ((> i 999999)
		   (format "%dM" (/ i 1000000)))
		  ((> i 999)
		   (format "%dK" (/ i 1000)))
		  (t
		   (format "%d" i))))
      (if (eq dir 'vertical)
	  (chart-goto-xy (+ (+ margin z) (if (oref a loweredge) 
					     (- (length s)) 1))
			 (chart-translate-ypos (oref a chart) i))
	(chart-goto-xy (chart-translate-xpos (oref a chart) i)
		       (+ margin z (if (oref a loweredge) -1 1))))
      (setq p1 (point))
      (insert s)
      (chart-zap-chars (length s))
      (put-text-property p1 (point) 'face (oref a labels-face))
      (setq i (+ i j))))
)

(defmethod chart-translate-namezone ((c chart) n)
  "Return a dot-pair representing the range of cols or rows in which
the nth name resides.  Automatically compensates for for direction."
  (let* ((dir (oref c direction))
	 (w (if (eq dir 'vertical) (oref c x-width) (oref c y-width)))
	 (m (if (eq dir 'vertical) (oref c y-margin) (oref c x-margin)))
	 (ns (length 
	      (oref (if (eq dir 'vertical) (oref c x-axis) (oref c y-axis))
		    items)))
	 (lpn (/ (float w) (float ns)))
	 )
    (cons (+ m 1 (round (* lpn (float n)))) 
	  (+ m (round (* lpn (+ 1 (float n))))))
    ))

(defmethod chart-axis-draw ((a chart-axis-names) &optional dir margin zone start end)
  "Draw axis information based upon a range to be spread along the edge"
  (call-next-method)
  ;; We prefer about 5 spaces between each value
  (let* ((i 0)
	 (s (oref a items))
	 (z (if zone zone 0))
	 (r nil)
	 (p nil)
	 (odd nil)
	 p1)
    (while s
      (setq odd (= (% (length s) 2) 1))
      (setq r (chart-translate-namezone (oref a chart) i))
      (setq p (- (+ (car r) (/ (- (cdr r) (car r)) 2)) (/ (length (car s)) 2)))
      (if (eq dir 'vertical)
	  (chart-goto-xy (+ (+ margin z) (if (oref a loweredge)
					     (- (length (car s)))
					   (length (car s))))
			 p)
	(chart-goto-xy p (+ (+ margin z) (if (oref a loweredge)
					     (if odd -2 -1)
					   (if odd 2 1)))))
      (setq p1 (point))
      (insert (car s))
      (chart-zap-chars (length (car s)))
      (put-text-property p1 (point) 'face (oref a labels-face))
      (setq i (+ i 1)
	    s (cdr s))))
)

(defmethod chart-draw-data ((c chart-bar))
  "Display the data available in a bar chart C"
  (let* ((data (oref c sequences))
	 (dir (oref c direction))
	 (odir (if (eq dir 'vertical) 'horizontal 'vertical))
	)
    (while data
      (if (stringp (car (oref (car data) data)))
	  ;; skip string lists...
	  nil
	;; display number lists...
	(let ((i 0)
	      (seq (oref (car data) data)))
	  (while seq
	    (let* ((rng (chart-translate-namezone c i))
		   (dp (if (eq dir 'vertical)
			   (chart-translate-ypos c (car seq))
			 (chart-translate-xpos c (car seq))))
		  (zp (if (eq dir 'vertical)
			  (chart-translate-ypos c 0)
			(chart-translate-xpos c 0)))
		  (fc (nth (% i (length chart-face-list)) chart-face-list))
		  )
	      (if (< dp zp)
		  (progn
		    (chart-draw-line dir (car rng) dp zp)
		    (chart-draw-line dir (cdr rng) dp zp))
		(chart-draw-line dir (car rng) zp (1+ dp))
		(chart-draw-line dir (cdr rng) zp (1+ dp)))
	      (if (= (car rng) (cdr rng)) nil
		(chart-draw-line odir dp (1+ (car rng)) (cdr rng))
		(chart-draw-line odir zp (car rng) (1+ (cdr rng))))
	      (if (< dp zp)
		  (chart-deface-rectangle dir rng (cons dp zp) fc)
		(chart-deface-rectangle dir rng (cons zp dp) fc))
	      )
	    ;; find the bounds, and chart it!
	    ;; for now, only do one!
	    (setq i (1+ i)
		  seq (cdr seq)))))
      (setq data (cdr data))))
  )

(defmethod chart-add-sequence ((c chart) &optional seq axis-label)
  "Adds to chart object C the sequence object SEQ.  If AXIS-LABEL,
then the axis stored in C is updated with the bounds of SEQ, or is
created with the bounds of SEQ."
  (if axis-label
      (let ((axis (oref-engine c axis-label)))
	(if (stringp (car (oref seq data)))
	    (let ((labels (oref seq data)))
	      (if (not axis)
		  (setq axis (make-instance chart-axis-names 
					    :name (oref seq name)
					    :items labels
					    :chart c))
		(oset axis items labels)))
	  (let ((range (cons 0 1))
		(l (oref seq data)))
	    (if (not axis)
		(setq axis (make-instance chart-axis-range
					  :name (oref seq name)
					  :chart c)))
	    (while l
	      (if (< (car l) (car range)) (setcar range (car l)))
	      (if (> (car l) (cdr range)) (setcdr range (car l)))
	      (setq l (cdr l)))
	    (oset axis bounds range)))
	(if (eq axis-label 'x-axis) (oset axis loweredge nil))
	(oset-engine c axis-label axis)
	))
  (oset c sequences (append (oref c sequences) (list seq))))

;;; Charting optimizers

(defmethod chart-trim ((c chart) max)
  "Trim all sequences in chart C to be at most MAX elements long"
  (let ((s (oref c sequences)))
    (while s
      (let ((sl (oref (car s) data)))
	(if (> (length sl) max)
	    (setcdr (nthcdr (1- max) sl) nil)))
      (setq s (cdr s))))
  )

(defmethod chart-sort ((c chart) pred)
  "Sort the data in chart C using predicate PRED.  See `chart-sort-matchlist'
for more details"
  (let* ((sl (oref c sequences))
	 (s1 (car sl))
	 (s2 (car (cdr sl)))
	 (s nil))
    (if (stringp (car (oref s1 data)))
	(progn
	  (chart-sort-matchlist s1 s2 pred)
	  (setq s (oref s1 data)))
      (if (stringp (car (oref s2 data)))
	  (progn
	    (chart-sort-matchlist s2 s1 pred)
	    (setq s (oref s2 data)))
	(error "Sorting of chart %s not supported" (object-name c))))
    (if (eq (oref c direction) 'horizontal)
	(oset (oref c y-axis) items s)
      (oset (oref c x-axis) items s)
	))
  )

(defun chart-sort-matchlist (namelst numlst pred)
  "Sort NAMELST and NUMLST (both SEQUENCE objects) based on predicate
PRED which should be the equivalent of '<, except it must expect two
cons cells of the form ( NAME . NUM ).  See SORT for more details."
  ;; 1 - create 1 list of cons cells
  (let ((newlist nil)
	(alst (oref namelst data))
	(ulst (oref numlst data)))
    (while alst
      ;; this is reversed, but were are sorting anyway
      (setq newlist (cons (cons (car alst) (car ulst)) newlist))
      (setq alst (cdr alst)
	    ulst (cdr ulst)))
    ;; 2 - Run sort routine on it
    (setq newlist (sort newlist pred)
	  alst nil
	  ulst nil)
    ;; 3 - Separate the lists
    (while newlist
      (setq alst (cons (car (car newlist)) alst)
	    ulst (cons (cdr (car newlist)) ulst))
      (setq newlist (cdr newlist)))
    ;; 4 - Store them back
    (oset namelst data (reverse alst))
    (oset numlst data (reverse ulst))))

;;; Utilities

(defun chart-goto-xy (x y)
  "Move cursor to position X Y in buffer, and add spaces and CRs if
needed."
  (let ((indent-tabs-mode nil)
	(num (goto-line (1+ y))))
    (if (and (= 0 num) (/= 0 (current-column))) (newline 1))
    (if (eobp) (newline num))
    ;; Now, a quicky column moveto/forceto method.
    (or (= (move-to-column x) x) 
	(let ((p (point)))
	  (indent-to x)
	  (remove-text-properties p (point) '(face))))))

(defun chart-zap-chars (n)
  "Zap up to N chars without deleteting EOLs"
  (if (not (eobp)) 
      (if (< n (- (save-excursion (end-of-line) (point)) (point)))
	  (delete-char n)
	(delete-region (point) (save-excursion (end-of-line) (point))))))

(defun chart-display-label (label dir zone start end &optional face)
  "Display label LABEL in direction DIR in column/row ZONE between 
START and END"
  (if (eq dir 'horizontal)
      (let (p1)
	(chart-goto-xy (+ start (- (/ (- end start) 2) (/ (length label) 2)))
		       zone)
	(setq p1 (point))
	(insert label)
	(chart-zap-chars (length label))
	(put-text-property p1 (point) 'face face)
	)
    (let ((i 0)
	  (stz (+ start (- (/ (- end start) 2) (/ (length label) 2)))))
      (while (< i (length label))
	(chart-goto-xy zone (+ stz i))
	(insert (aref label i))
	(chart-zap-chars 1)
	(put-text-property (1- (point)) (point) 'face face)
	(setq i (1+ i))))))

(defun chart-draw-line (dir zone start end)
  "Draw a line using line-drawing characters in direction DIR using
column or row ZONE between START and END"
  (chart-display-label 
   (make-string (- end start) (if (eq dir 'vertical) ?| ?\-))
   dir zone start end))

(defun chart-deface-rectangle (dir r1 r2 face)
  "Colorize a rectangle in direction DIR across range R1 by range R2 (dotted
pairs) with FACE"
  (let* ((range1 (if (eq dir 'vertical) r1 r2))
	 (range2 (if (eq dir 'vertical) r2 r1))
	 (y (car range2)))
    (while (<= y (cdr range2))
      (chart-goto-xy (car range1) y)
      (put-text-property (point) (+ (point) (1+ (- (cdr range1) (car range1))))
			 'face face)
      (setq y (1+ y)))))

;;; Helpful `I don't want to learn eieio just now' washover functions

(defun chart-bar-quickie (dir title namelst nametitle numlst numtitle
			      &optional max sort-pred)
  "Wash over the complex eieio stuff and create a nice bar chart with
going in direction DIR ['horizontal 'vertical] with TITLE using a name
sequence NAMELST labeled NAMETITLE with values NUMLST labeled NUMTITLE.
Optional arguments:
Set the charts' max element display to MAX, and sort lists with
SORT-PRED if desired."
  (let ((nc (make-instance chart-bar
			   :title title
			   :key-label "8-m"  ; This is a text key pic
			   :direction dir
			   ))
	(iv (eq dir 'vertical)))
    (chart-add-sequence nc
			(make-instance chart-sequece
				       :data namelst
				       :name nametitle)
			(if iv 'x-axis 'y-axis))
    (chart-add-sequence nc
			(make-instance chart-sequece
				       :data numlst
				       :name numtitle)
			(if iv 'y-axis 'x-axis))
    (if sort-pred (chart-sort nc sort-pred))
    (if (integerp max) (chart-trim nc max))
    (switch-to-buffer (chart-new-buffer nc))
    (chart-draw nc)))

;;; Test code

(defun chart-test-it-all ()
  "Test out various charting features"
  (interactive)
  (chart-bar-quickie 'vertical "Test Bar Chart"
		     '( "U1" "ME2" "C3" "B4" "QT" "EZ") "Items"
		     '( 5 -10 23 20 30 -3) "Values")
  )

;;; Sample utility function

(defun chart-file-count (dir)
  "Draw a chart which displays the number of files of different
extentions in directory DIR."
  (interactive "DDirectory: ")
  (if (not (string-match "/$" dir))
      (setq dir (concat dir "/")))
  (message "Collecting statistics...")
  (let ((flst (directory-files dir nil nil t))
	(extlst (list "<dir>"))
	(cntlst (list 0)))
    (while flst
      (let* ((j (string-match "[^\\.]\\(\\.[a-zA-Z]+\\|~\\|#\\)$" (car flst)))
	     (s (if (file-accessible-directory-p (concat dir (car flst)))
		    "<dir>"
		  (if j 
		      (substring (car flst) (match-beginning 1) (match-end 1))
		    nil)))
	     (m (member s extlst)))
	(if (not s) nil
	  (if m
	      (let ((cell (nthcdr (- (length extlst) (length m)) cntlst)))
		(setcar cell (1+ (car cell))))
	    (setq extlst (cons s extlst)
		  cntlst (cons 1 cntlst)))))
      (setq flst (cdr flst)))
    ;; Lets create the chart!
    (chart-bar-quickie 'vertical "Files Extension Distribution"
		       extlst "File Extensions"
		       cntlst "# of occurances"
		       10
		       '(lambda (a b) (> (cdr a) (cdr b))))
    ))

(defun chart-space-usage (d)
  "Display a top usage chart for directory D"
  (interactive "DDirectory: ")
  (message "Collecting statistics...")
  (let ((nmlst nil)
	(cntlst nil)
	(b (get-buffer-create " *du-tmp*")))
    (set-buffer b)
    (erase-buffer)
    (insert "cd " d ";/bin/du -sk * \n")
    (message "Running `cd %s;du -sk *'..." d)
    (call-process-region (point-min) (point-max) "csh" t
			 (current-buffer) nil)
    (goto-char (point-min))
    (message "Scanning output ...")
    (while (re-search-forward "^\\([0-9]+\\)[ \t]+\\([^ \n]+\\)$" nil t)
      (let* ((nam (buffer-substring (match-beginning 2) (match-end 2)))
	     (num (buffer-substring (match-beginning 1) (match-end 1))))
	(setq nmlst (cons nam nmlst)
	      ;; * 1000 to put it into bytes
	      cntlst (cons (* (string-to-int num) 1000) cntlst))))
    (if (not nmlst)
	(error "No files found!"))
    (chart-bar-quickie 'vertical (format "Largest files in %s" d)
		       nmlst "File Name"
		       cntlst "File Size"
		       10
		       '(lambda (a b) (> (cdr a) (cdr b))))
    ))

(defun chart-emacs-storage ()
  "Chart the current storage requirements of emacs"
  (interactive)
  (let* ((data (garbage-collect))
	 (names '("conses" "free cons" "syms" "free syms" 
		  "markers" "free mark" "floats" "free flt" 
		  "strings/2" "vectors"))
	 (nums (list (car (car data))
		     (cdr (car data))
		     (car (nth 1 data))
		     (cdr (nth 1 data))
		     (car (nth 2 data))
		     (cdr (nth 2 data))
		     (car (nth 5 data))
		     (cdr (nth 5 data))
		     (/ (nth 3 data) 2)
		     (nth 4 data))))
    ;; Lets create the chart!
    (chart-bar-quickie 'vertical "Emacs Runtime Storage Usage"
		       names "Storage Items"
		       nums "Objects")))

(defun chart-emacs-lists ()
  "Chart out the size of various important lists"
  (interactive)
  (let* ((names '("buffers" "frames" "processes" "faces" "x-displays"
		  ))
	 (nums (list (length (buffer-list))
		     (length (frame-list))
		     (length (process-list))
		     (length (face-list))
		     (length (x-display-list))
		     
		)))
    ;; Lets create the chart!
    (chart-bar-quickie 'vertical "Emacs List Size Chart"
		       names "Various Lists"
		       nums "Objects")))

(defun chart-rmail-from ()
  "If we are in an rmail summary buffer, then chart out the froms."
  (interactive)
  (if (not (eq major-mode 'rmail-summary-mode))
      (error "You must invoke chart-rmail-from in an rmail summary buffer"))
  (let ((nmlst nil)
	(cntlst nil))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\-[A-Z][a-z][a-z] +\\(\\w+\\)@\\w+" nil t)
	(let* ((nam (buffer-substring (match-beginning 1) (match-end 1)))
	       (m (member nam nmlst)))
	  (message "Scanned username %s" nam)
	  (if m
	      (let ((cell (nthcdr (- (length nmlst) (length m)) cntlst)))
		(setcar cell (1+ (car cell))))
	    (setq nmlst (cons nam nmlst)
		  cntlst (cons 1 cntlst))))))
    (chart-bar-quickie 'vertical "Username Occurance in RMAIL box"
		       nmlst "User Names"
		       cntlst "# of occurances"
		       10
		       '(lambda (a b) (> (cdr a) (cdr b))))
    ))

;;; end of lisp
(provide 'chart)

