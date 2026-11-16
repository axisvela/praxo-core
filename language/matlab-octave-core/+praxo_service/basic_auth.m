function header = basic_auth(client_id, client_secret)
header = '';
if ~ischar(client_id) || isempty(client_id)
    return;
end
if ~ischar(client_secret)
    client_secret = '';
end
header = ['Basic ' base64_encode([client_id ':' client_secret])];
end

function text = base64_encode(raw)
alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
bytes = double(raw);
text = '';
for i = 1:3:numel(bytes)
    chunk = bytes(i:min(i + 2, numel(bytes)));
    b1 = chunk(1);
    b2 = 0;
    b3 = 0;
    if numel(chunk) >= 2
        b2 = chunk(2);
    end
    if numel(chunk) >= 3
        b3 = chunk(3);
    end
    value = b1 * 65536 + b2 * 256 + b3;
    text = [text alphabet(floor(value / 262144) + 1) ...
        alphabet(mod(floor(value / 4096), 64) + 1) ...
        alphabet(mod(floor(value / 64), 64) + 1) ...
        alphabet(mod(value, 64) + 1)];
    if numel(chunk) == 1
        text(end - 1:end) = '==';
    elseif numel(chunk) == 2
        text(end) = '=';
    end
end
end
