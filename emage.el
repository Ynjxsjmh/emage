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

(require 'seq)


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

(defcustom emage-image-extension "jpg"
  "Image extension saved to file system."
  :type 'string
  :group 'emage)

(defcustom emage-buffer "*emage*"
  "The buffer name of search result."
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

  (let* ((temp-image-name (emage--image-name-generator))
         (input-image-extension (read-string (format "Input image extension (default %s):" emage-image-extension)))
         (image-extension (if (string= "" input-image-extension)
                              emage-image-extension
                            input-image-extension))
         (relative-temp-image-path (concat (emage--image-dir) "/" temp-image-name "." image-extension)))

    (emage--image-to-file-system relative-temp-image-path)

    (let* ((input-image-name (read-string (format "Input image name (%s): " (emage--image-name-generator-description)) ))
           (image-name (if (string= "" input-image-name)
                           (concat temp-image-name "." image-extension)
                         (concat input-image-name "." image-extension)))

           (relative-image-path (concatenate 'string (emage--image-dir) "/" image-name))
           (image-alt-text (read-string "Input image alt text (default empty): ")))

      (rename-file relative-temp-image-path relative-image-path)
      (insert (emage--insert-image-path-as-link relative-image-path image-alt-text)))))

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
  (let* ((extension (file-name-extension image-path))
         (image-mime-type (emage--image-extension-to-image-mime-type extension)))
    (cond
     ((string= system-type "darwin")
      (call-process-shell-command "convert" nil nil nil nil (concat "\"" image-path "\" -resize  \"50%\"" ) (concat "\"" image-path "\"" )))
     ((string= system-type "gnu/linux")
      (call-process-shell-command (concat "xclip -selection clipboard -target image/" image-mime-type "-o > " image-path)))
     ((string= system-type "windows-nt")
      (shell-command (concat "powershell -command \"Add-Type -AssemblyName System.Windows.Forms;if ($([System.Windows.Forms.Clipboard]::ContainsImage())) {$image = [System.Windows.Forms.Clipboard]::GetImage();[System.Drawing.Bitmap]$image.Save('" image-path "',[System.Drawing.Imaging.ImageFormat]::" image-mime-type "); Write-Output 'clipboard content saved as file'} else {Write-Output 'clipboard does not contain image data'}\""))))))

(defun emage--image-extension-to-image-mime-type (image-extension)
  "Convert IMAGE-EXTENSION to its corresponding MIME type.
If the extension is not found, return nil."
  (let ((image-mime-types
         (make-hash-table :test 'equal)))
    (puthash "jpg"  "jpeg" image-mime-types)
    (puthash "jpeg" "jpeg" image-mime-types)
    (puthash "png"  "png"  image-mime-types)
    (puthash "tiff" "tiff" image-mime-types)
    (puthash "bmp"  "bmp"  image-mime-types)
    (puthash "webp" "webp" image-mime-types)

    ;; Attempt to get the mime type for the given extension
    (let ((mime-type (gethash image-extension image-mime-types)))
      (if mime-type
          mime-type
        (error "Unsupported image extension: %s" image-extension)))))


(defun emage-yank-image-at-point-to-clipboard ()
  "Yank image at point to clipboard as image/png."
  (interactive)
  (let ((image (get-text-property (point) 'display)))
    (if (eq (car image) 'image)
        (let ((file (plist-get (cdr image) ':file)))
          (emage--image-to-clipboard file))
      (message "Point is not at an image."))))

(defun emage-yank-image-at-line-to-clipboard ()
  "Yank image link at line as image to clipboard as image/png."
  (interactive)
  (let ((line-str (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
    (if (string-match "\\./.+?\\.png" line-str)
        (let ((image-path (match-string 0 line-str)))
          (emage--image-to-clipboard image-path))
      (message "There is no image link at line."))))

(defun emage--image-to-clipboard (image-path)
  (cond
   ((string= system-type "gnu/linux")
    (start-process
     "xclip-proc" nil "xclip"
     "-i" "-selection" "clipboard" "-t" "image/png"
     "-quiet" image-path))
   ((string= system-type "windows-nt")
    (shell-command (concat "powershell -command \"Add-Type -AssemblyName System.Drawing; Add-Type -AssemblyName System.Windows.Forms; $file = get-item('" image-path "'); $img = [System.Drawing.Image]::Fromfile($file); [System.Windows.Forms.Clipboard]::SetImage($img); Write-Output 'image saved to clipboard';\""))))
  (message "Image %S yanked to clipboard." (file-name-nondirectory image-path)))

(defun emage--view-image (image-path)
  (let ((image-name (concat "*" (file-name-nondirectory image-path) "*")))

    (if (get-buffer image-name)
        (with-current-buffer image-name
          (let ((inhibit-read-only t))
            ;; Erase buffer content.
            (read-only-mode -1)
            (erase-buffer)))
      (generate-new-buffer image-name))

    (with-current-buffer image-name
      (insert-image (create-image image-path)))

    (pop-to-buffer image-name)))

(defun emage--delete-image (image-path)
  (move-file-to-trash image-path)
  (message "File %S moved to trash" (file-name-nondirectory image-path))
  )

(defun emage-list-unreferenced-images-by-current-file ()
  (interactive)
  ;; List images not appeared in current file
  (let* ((buffer-emage-image-dir (emage--image-dir))
         (buffer-folder (file-name-directory buffer-file-name))
         (buffer-string (buffer-substring-no-properties (point-min) (point-max)))
         (image-names (mapcar 'file-name-nondirectory (directory-files-recursively (emage--image-dir) "")))
         (unreferenced-image-names (seq-filter (lambda (image-name) (not (string-match-p (regexp-quote image-name) buffer-string))) image-names))
         (unreferenced-image-paths (mapcar (lambda (image-name) (concat (file-name-as-directory buffer-folder) (file-name-as-directory buffer-emage-image-dir) image-name)) unreferenced-image-names)))

    (emage--fill-unreferenced-images-to-buffer unreferenced-image-paths buffer-emage-image-dir)

    ;; Pop search buffer.
    (pop-to-buffer emage-buffer)
    (goto-char (point-min))))

(defun emage--fill-unreferenced-images-to-buffer (unreferenced-image-paths buffer-emage-image-dir)
  ;; Erase or create search result.
  (if (get-buffer emage-buffer)
      (with-current-buffer emage-buffer
        (let ((inhibit-read-only t))
          ;; Erase buffer content.
          (read-only-mode -1)
          (erase-buffer)))
    (generate-new-buffer emage-buffer))

  (with-current-buffer emage-buffer
    (mapcar (lambda (image-path)
              (insert-button "VIEW"
                             'follow-link t
                             'action (lambda (_arg) (emage--view-image image-path))
                             'help-echo "View image")
              (insert "   ")
              (insert-button "DEL"
                             'follow-link t
                             'action (lambda (_arg)
                                       (emage--delete-image image-path)
                                       (emage-fill-unreferenced-images-to-buffer (seq-filter (lambda (unreferenced-image-path) (not (string-equal unreferenced-image-path image-path))) unreferenced-image-paths) buffer-emage-image-dir))
                             'help-echo "Delete image")
              (insert "   ")
              (insert (concat (file-name-as-directory buffer-emage-image-dir) (file-name-nondirectory image-path)))
              (insert "\n")) unreferenced-image-paths)))

(provide 'emage)
;;; emage.el ends here
