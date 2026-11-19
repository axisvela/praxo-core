       >>source format free
identification division.
program-id. plugin-process-tests.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 host-handle usage pointer.
01 call-result usage binary-long.
01 error-buffer pic x(256).
01 response-buffer pic x(8192).
01 python-path pic x(1024).
01 fixture-path pic x(2048).
procedure division.
    accept python-path from environment "PRAXO_PYTHON"
    accept fixture-path from environment "PRAXO_PLUGIN_FIXTURE"
    move low-values to error-buffer response-buffer
    call static "px_plugin_process_start_simple" using
        by reference z"com.example.echo"
        by reference concatenate(trim(python-path), x"00")
        by reference concatenate(trim(fixture-path), x"00")
        by reference z"test-token"
        by reference host-handle error-buffer
        by value length of error-buffer
        returning call-result
    if call-result = 0
        display "plugin start failed: " error-buffer
        stop run returning 1
    end-if
    call static "px_plugin_process_invoke_simple" using
        by value host-handle
        by reference z"tool.provider" z"echo" z'{"text":"hi"}'
        by reference response-buffer
        by value length of response-buffer
        by reference error-buffer
        by value length of error-buffer
        returning call-result
    if call-result = 0 or response-buffer(1:13) not = '{"text":"hi"}'
        call static "px_plugin_process_stop_simple" using
            by value host-handle
        display "plugin invoke failed: " error-buffer
        stop run returning 1
    end-if
    call static "px_plugin_process_invoke_simple" using
        by value host-handle
        by reference z"tool.provider" z"denied" z""
        by reference response-buffer
        by value length of response-buffer
        by reference error-buffer
        by value length of error-buffer
        returning call-result
    if call-result not = 0 or error-buffer(1:17) not = "CAPABILITY_DENIED"
        call static "px_plugin_process_stop_simple" using
            by value host-handle
        display "plugin denial failed: " error-buffer
        stop run returning 1
    end-if
    call static "px_plugin_process_invoke_simple" using
        by value host-handle
        by reference z"tool.provider" z"echo" z"still-active"
        by reference response-buffer
        by value length of response-buffer
        by reference error-buffer
        by value length of error-buffer
        returning call-result
    call static "px_plugin_process_stop_simple" using
        by value host-handle
    set host-handle to null
    if call-result = 0 or response-buffer(1:12) not = "still-active"
        display "plugin recovery failed: " error-buffer
        stop run returning 1
    end-if
    call static "px_plugin_process_stop_simple" using
        by value host-handle
    display "COBOL plugin process tests passed"
    stop run returning 0.
