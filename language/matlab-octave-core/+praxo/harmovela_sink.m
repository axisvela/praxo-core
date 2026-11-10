function sink = harmovela_sink(baseUrl, source, specVersion, transport, clock)
if nargin < 2 || isempty(source), source = 'praxo-core'; end
if nargin < 3 || isempty(specVersion), specVersion = '0.2'; end
if nargin < 4, transport = []; end
if nargin < 5, clock = []; end
sink = struct('baseUrl', baseUrl, 'source', source, ...
    'specVersion', specVersion, 'transport', transport, 'clock', clock);
end
