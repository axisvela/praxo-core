function model = fallback_model(primary, fallback)
model = @(request) fallback_generate(primary, fallback, request);
end

function response = fallback_generate(primary, fallback, request)
try
    response = primary(request);
catch
    response = fallback(request);
end
end
