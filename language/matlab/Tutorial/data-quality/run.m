here = fileparts(mfilename('fullpath'));
language = fileparts(fileparts(fileparts(here)));
addpath(fullfile(language, 'matlab-octave-core'));
addpath(here);
data_quality();
