;;; emage.el --- Save clipboard image to file system, and insert file link to current point. Yank image at point to clipboard. -*- lexical-binding: t -*-

;; Author: Ynjxsjmh <ynjxsjmh@gmail.com>
;; URL: https://github.com/Ynjxsjmh/emage
;; Description: Save clipboard image to disk file, and insert file link to current point.
;; Created: <2020-09-23 Wed 18:11>
;; Version: 3.0
;; Last-Updated: <2020-09-24 Thu 11:12>
;;           By: Ynjxsjmh

;; Keywords: image, yank, paste
;;


;;; This file is NOT part of GNU Emacs

;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; Save clipboard image to disk file, and insert file link to current point.
;;
;; This is an Emacs extension, with which you can just use one key to save
;; clipboard image to file system, and at the same time insert the
;; file link(org-mode/markdown-mode/adoc-mode) or file path(other mode)
;; to current point.  Also you can yank image at point to clipboard.

;;; Code:


(defgroup emage nil
  "Image yank and insert for Emacs."
  :group 'emage)

(defcustom emage-image-dir nil
  "If set, images will be stored in this directory instead of current directory.
See `emage--image-dir' for more info."
  :type '(choice
          (const :tag "Default" nil)
          (string :tag "Directory"))
  :group 'emage)
(make-variable-buffer-local 'emage-image-dir)

(defcustom emage-image-name-generator nil
  "If set, image name generator strategy will be replaced by user customization.
See `emage--image-name-generator' for more info."
  :type 'function
  :group 'emage)

(defcustom emage-image-name-generator-description nil
  "If set, image name generator strategy description will be replaced by user customization.
See `emage--image-name-generator-description' for more info."
  :type 'string
  :group 'emage)

(defun emage--image-dir ()
  "Return the directory path for image saving of current buffer.
It's `emage-image-dir', unless it's nil.  Then it's current directory."
  (if emage-image-dir
      (concatenate 'string "./" emage-image-dir)
    "."))

(defun emage--default-image-name-generator ()
  (make-temp-name (concat (format-time-string "%Y%m%d_%H%M%S_")) ))

(defun emage--image-name-generator ()
  (if emage-image-name-generator
      (funcall emage-image-name-generator)
    (funcall #'emage--default-image-name-generator)))

(defun emage--image-name-generator-description ()
  (or emage-image-name-generator-description "default current timestamp with random string"))


(defun emage-insert-clipboard-image-to-point ()
  "Save image in the clipboard to file system.
Then insert image relative path as image link to the current point."
  (interactive)

  (unless (file-directory-p (emage--image-dir))
    (make-directory (emage--image-dir) :parents))

  (let* (
         (input-image-name (read-string (format "Input image name (%s): " (emage--image-name-generator-description)) ))
         (image-name (if (string= "" input-image-name)
                         (concat (emage--image-name-generator) ".png")
                       (concat input-image-name ".png")))

         (relative-image-path (concatenate 'string (emage--image-dir) "/" image-name))
         (image-alt-text (read-string "Input image alt text (default empty): "))
         )

    (emage--image-to-file-system relative-image-path)
    (insert (emage--insert-image-path-as-link relative-image-path image-alt-text))))

(defun emage--insert-image-path-as-link (image-path image-alt-text)
  (cond
   ((string-equal major-mode "markdown-mode") (format "![%s](%s)" image-alt-text image-path))
   ((string-equal major-mode "gfm-mode") (format "![%s](%s)" image-alt-text image-path))
   ((string-equal major-mode "adoc-mode") (format "image::%s[%s]\n" image-path image-alt-text))
   ((string-equal major-mode "org-mode") (progn
                                           (if (string-empty-p image-alt-text)
                                               (format "[[%s]]" image-path)
                                             (format "[[%s][%s]]" image-path image-alt-text))))
   (t (progn
        (if (string-empty-p image-alt-text)
            image-path
          (format "%s: %s" image-alt-text image-path))))))

(defun emage--image-to-file-system (image-path)
  (cond
   ((string= system-type "darwin")
    (call-process-shell-command "convert" nil nil nil nil (concat "\"" image-path "\" -resize  \"50%\"" ) (concat "\"" image-path "\"" )))
   ((string= system-type "gnu/linux")
    (call-process-shell-command (concat "xclip -selection clipboard -t image/png -o > " image-path)))
   ((string= system-type "windows-nt")
    (shell-command (concat "powershell -command \"Add-Type -AssemblyName System.Windows.Forms;if ($([System.Windows.Forms.Clipboard]::ContainsImage())) {$image = [System.Windows.Forms.Clipboard]::GetImage();[System.Drawing.Bitmap]$image.Save('" image-path "',[System.Drawing.Imaging.ImageFormat]::Png); Write-Output 'clipboard content saved as file'} else {Write-Output 'clipboard does not contain image data'}\"")))))


(defun emage-yank-image-at-point-to-clipboard ()
  "Yank image at point to clipboard as image/png."
  (interactive)
  (let ((image (get-text-property (point) 'display)))
    (if (eq (car image) 'image)
        (let ((file (plist-get (cdr image) ':file)))
          (emage--image-to-clipboard file))
      (message "Point is not at an image."))))

(defun emage--image-to-clipboard (image-path)
  (cond
   ((string= system-type "gnu/linux")
    (start-process
     "xclip-proc" nil "xclip"
     "-i" "-selection" "clipboard" "-t" "image/png"
     "-quiet" image-path))
   ((string= system-type "windows-nt")
    (shell-command (concat "powershell -command \"Add-Type -AssemblyName System.Drawing; Add-Type -AssemblyName System.Windows.Forms; $file = get-item('" image-path "'); $img = [System.Drawing.Image]::Fromfile($file); [System.Windows.Forms.Clipboard]::SetImage($img); Write-Output 'image saved to clipboard';\"")))))


(provide 'emage)
;;; emage.el ends here
