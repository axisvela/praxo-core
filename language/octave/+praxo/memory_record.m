function value = memory_record(id, frame, content, createdAt)
if nargin < 4, createdAt = ''; end
value = struct('id', id, 'frame', frame, 'content', content, 'createdAt', createdAt);
end
