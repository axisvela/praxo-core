function retry_example()
    [output, calls] = run_retry(2, 3);
    assert(strcmp(output, 'status: green') && calls == 3);
    [output, code, calls] = run_retry(3, 3);
    assert(isempty(output) && strcmp(code, 'MODEL_UNAVAILABLE') && calls == 3);
    fprintf('MATLAB retry example passed\n');
end

function [output, code, calls] = run_retry(failures, max_attempts)
    output = '';
    code = '';
    calls = max_attempts;
    for attempt = 1:max_attempts
        if attempt > failures
            output = 'status: green';
            calls = attempt;
            return;
        end
    end
    code = 'MODEL_UNAVAILABLE';
end
