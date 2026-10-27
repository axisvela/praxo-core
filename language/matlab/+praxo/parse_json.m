function node = parse_json(raw)
if ~ischar(raw) || (~isrow(raw) && ~isempty(raw))
    error('praxo:json', 'JSON input must be a character row vector');
end
s = double(raw);
n = numel(s);
if n > 1048576
    error('praxo:json', 'JSON input exceeds capacity');
end
p = 1;
node = parse_value(0);
skip_space();
if p <= n
    error('praxo:json', 'Trailing JSON content');
end

    function skip_space()
        while p <= n && any(s(p) == [32 9 10 13])
            p = p + 1;
        end
    end

    function v = parse_value(depth)
        if depth > 64
            error('praxo:json', 'JSON nesting exceeds capacity');
        end
        skip_space();
        if p > n
            error('praxo:json', 'Expected JSON value');
        end
        c = s(p);
        if c == 123
            p = p + 1;
            items = cell(0, 2);
            skip_space();
            if p <= n && s(p) == 125
                p = p + 1;
            else
                while true
                    skip_space();
                    if p > n || s(p) ~= 34
                        error('praxo:json', 'Expected object key');
                    end
                    key = parse_string();
                    skip_space();
                    if p > n || s(p) ~= 58
                        error('praxo:json', 'Expected colon');
                    end
                    p = p + 1;
                    value = parse_value(depth + 1);
                    items(end + 1, :) = {key, value};
                    skip_space();
                    if p <= n && s(p) == 125
                        p = p + 1;
                        break;
                    end
                    if p > n || s(p) ~= 44
                        error('praxo:json', 'Expected object separator');
                    end
                    p = p + 1;
                end
            end
            v = struct('kind', 'object', 'value', {items});
        elseif c == 91
            p = p + 1;
            items = cell(1, 0);
            skip_space();
            if p <= n && s(p) == 93
                p = p + 1;
            else
                while true
                    items{end + 1} = parse_value(depth + 1);
                    skip_space();
                    if p <= n && s(p) == 93
                        p = p + 1;
                        break;
                    end
                    if p > n || s(p) ~= 44
                        error('praxo:json', 'Expected array separator');
                    end
                    p = p + 1;
                end
            end
            v = struct('kind', 'array', 'value', {items});
        elseif c == 34
            v = struct('kind', 'string', 'value', parse_string());
        elseif c == 116
            literal('true');
            v = struct('kind', 'boolean', 'value', true);
        elseif c == 102
            literal('false');
            v = struct('kind', 'boolean', 'value', false);
        elseif c == 110
            literal('null');
            v = struct('kind', 'null', 'value', []);
        elseif c == 45 || (c >= 48 && c <= 57)
            start = p;
            if s(p) == 45
                p = p + 1;
            end
            if p > n
                error('praxo:json', 'Invalid number');
            end
            if s(p) == 48
                p = p + 1;
            elseif s(p) >= 49 && s(p) <= 57
                digits();
            else
                error('praxo:json', 'Invalid number');
            end
            if p <= n && s(p) == 46
                p = p + 1;
                digits();
            end
            if p <= n && (s(p) == 101 || s(p) == 69)
                p = p + 1;
                if p <= n && (s(p) == 43 || s(p) == 45)
                    p = p + 1;
                end
                digits();
            end
            number = str2double(char(s(start:p-1)));
            if ~isfinite(number)
                error('praxo:json', 'Number is not finite');
            end
            v = struct('kind', 'number', 'value', number);
        else
            error('praxo:json', 'Invalid JSON value');
        end
    end

    function digits()
        start = p;
        while p <= n && s(p) >= 48 && s(p) <= 57
            p = p + 1;
        end
        if p == start
            error('praxo:json', 'Expected digit');
        end
    end

    function literal(text)
        len = numel(text);
        if p + len - 1 > n || ~isequal(s(p:p+len-1), double(text))
            error('praxo:json', 'Invalid literal');
        end
        p = p + len;
    end

    function text = parse_string()
        p = p + 1;
        bytes = [];
        while p <= n
            c = s(p);
            p = p + 1;
            if c == 34
                text = char(bytes);
                return;
            elseif c == 92
                if p > n
                    error('praxo:json', 'Incomplete escape');
                end
                e = s(p);
                p = p + 1;
                if any(e == [34 92 47])
                    bytes(end + 1) = e;
                elseif e == 98
                    bytes(end + 1) = 8;
                elseif e == 102
                    bytes(end + 1) = 12;
                elseif e == 110
                    bytes(end + 1) = 10;
                elseif e == 114
                    bytes(end + 1) = 13;
                elseif e == 116
                    bytes(end + 1) = 9;
                elseif e == 117
                    cp = hex4();
                    if cp >= 55296 && cp <= 56319
                        if p + 1 > n || s(p) ~= 92 || s(p + 1) ~= 117
                            error('praxo:json', 'Missing low surrogate');
                        end
                        p = p + 2;
                        low = hex4();
                        if low < 56320 || low > 57343
                            error('praxo:json', 'Invalid low surrogate');
                        end
                        cp = 65536 + (cp - 55296) * 1024 + low - 56320;
                    elseif cp >= 56320 && cp <= 57343
                        error('praxo:json', 'Unexpected low surrogate');
                    end
                    if cp < 128
                        bytes(end + 1) = cp;
                    elseif cp < 2048
                        bytes = [bytes 192 + floor(cp / 64) 128 + mod(cp, 64)];
                    elseif cp < 65536
                        bytes = [bytes 224 + floor(cp / 4096) 128 + mod(floor(cp / 64), 64) 128 + mod(cp, 64)];
                    else
                        bytes = [bytes 240 + floor(cp / 262144) 128 + mod(floor(cp / 4096), 64) 128 + mod(floor(cp / 64), 64) 128 + mod(cp, 64)];
                    end
                else
                    error('praxo:json', 'Invalid escape');
                end
            elseif c < 32 || c > 255
                error('praxo:json', 'Invalid string character');
            elseif c < 128
                bytes(end + 1) = c;
            else
                if c >= 194 && c <= 223
                    count = 1; cp = c - 192; minimum = 128;
                elseif c >= 224 && c <= 239
                    count = 2; cp = c - 224; minimum = 2048;
                elseif c >= 240 && c <= 244
                    count = 3; cp = c - 240; minimum = 65536;
                else
                    error('praxo:json', 'Invalid UTF-8');
                end
                if p + count - 1 > n
                    error('praxo:json', 'Incomplete UTF-8');
                end
                seq = s(p:p+count-1);
                if any(seq < 128 | seq > 191)
                    error('praxo:json', 'Invalid UTF-8 continuation');
                end
                for k = 1:count
                    cp = cp * 64 + seq(k) - 128;
                end
                if cp < minimum || cp > 1114111 || (cp >= 55296 && cp <= 57343)
                    error('praxo:json', 'Invalid UTF-8 code point');
                end
                bytes = [bytes c seq];
                p = p + count;
            end
        end
        error('praxo:json', 'Unterminated string');
    end

    function value = hex4()
        if p + 3 > n
            error('praxo:json', 'Incomplete Unicode escape');
        end
        value = 0;
        for j = 1:4
            c = s(p);
            p = p + 1;
            if c >= 48 && c <= 57
                digit = c - 48;
            elseif c >= 65 && c <= 70
                digit = c - 65 + 10;
            elseif c >= 97 && c <= 102
                digit = c - 97 + 10;
            else
                error('praxo:json', 'Invalid Unicode escape');
            end
            value = value * 16 + digit;
        end
    end
end
