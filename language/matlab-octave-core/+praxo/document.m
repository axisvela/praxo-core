function value = document(id, content, metadata, score)
if nargin < 2 || isempty(content), content = ''; end
if nargin < 3 || isempty(metadata), metadata = struct(); end
if nargin < 4 || isempty(score), score = 0; end
value = struct('id', id, 'content', content, 'metadata', metadata, 'score', score);
end
