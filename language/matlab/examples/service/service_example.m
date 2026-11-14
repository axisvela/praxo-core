function service_example()
    [status, ~] = handle('GET', '/healthz', '', '');
    assert(status == 200);
    [status, ~] = handle('POST', '/run', '', '{"prompt":"hi"}');
    assert(status == 401);
    [status, body] = handle('POST', '/run', 'user-1', '{"prompt":"hi"}');
    assert(status == 200 && ~isempty(strfind(body, 'hello from the service')));
    disp('MATLAB service example passed');
end

function [status, body] = handle(method, path, principal, request_body)
    if strcmp(method, 'GET') && strcmp(path, '/healthz')
        status = 200; body = '{"status":"ok"}'; return;
    end
    if ~strcmp(method, 'POST') || ~strcmp(path, '/run')
        status = 404; body = '{"error":"not found"}'; return;
    end
    if isempty(principal)
        status = 401; body = '{"error":"missing X-Praxo-Principal"}'; return;
    end
    if isempty(strfind(request_body, '"prompt"'))
        status = 400; body = '{"error":"prompt is required"}'; return;
    end
    status = 200; body = '{"output":"hello from the service"}';
end
