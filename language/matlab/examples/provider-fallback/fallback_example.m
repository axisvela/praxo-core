function fallback_example()
    assert(strcmp(run_fallback(false, false), 'primary'));
    assert(strcmp(run_fallback(true, false), 'fallback'));
    assert(strcmp(run_fallback(true, true), 'MODEL_UNAVAILABLE'));
    fprintf('MATLAB provider fallback example passed\n');
end

function output = run_fallback(primary_fails, fallback_fails)
    if ~primary_fails
        output = 'primary';
    elseif ~fallback_fails
        output = 'fallback';
    else
        output = 'MODEL_UNAVAILABLE';
    end
end
