;;;; PRAXO-CORE bridge wrapper for Common Lisp (SBCL).

(defun read-all (stream)
  (with-output-to-string (result)
    (loop for character = (read-char stream nil nil)
          while character
          do (write-char character result))))

(defun fail (message)
  (format *error-output* "~A~%" message)
  (finish-output *error-output*)
  (sb-ext:exit :code 1))

(defun main ()
  (let* ((binary (sb-ext:posix-getenv "PRAXO_BRIDGE_BIN"))
         (arguments (cdr sb-ext:*posix-argv*))
         (command (if (and binary (plusp (length binary)))
                      (list binary)
                      (list "go" "run" "./cmd/praxo-bridge")))
         process)
    (handler-case
        (setf process
              (sb-ext:run-program (first command)
                                  (append (rest command) arguments)
                                  :input :stream
                                  :output :stream
                                  :error :stream
                                  :wait nil
                                  :external-format :utf-8))
      (error (condition)
        (fail (format nil "Cannot start praxo-bridge: ~A" condition))))
    (handler-case
        (with-open-stream (input (sb-ext:process-input process))
          (loop for character = (read-char *standard-input* nil nil)
                while character
                do (write-char character input))
          (finish-output input))
      (error (condition)
        (sb-ext:process-kill process 1)
        (fail (format nil "Cannot forward input: ~A" condition))))
    (let ((output (read-all (sb-ext:process-output process)))
          (diagnostics (read-all (sb-ext:process-error process))))
      (sb-ext:process-wait process)
      (write-string output *standard-output*)
      (finish-output *standard-output*)
      (write-string diagnostics *error-output*)
      (finish-output *error-output*)
      (sb-ext:exit :code (or (sb-ext:process-exit-code process) 1)))))

(main)
