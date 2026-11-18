here = fileparts(mfilename('fullpath'));
language = fileparts(fileparts(fileparts(here)));
addpath(fullfile(language, 'matlab-octave-core'));
addpath(fullfile(language, 'matlab', 'examples', 'advanced-delegation'));
governance_example();
