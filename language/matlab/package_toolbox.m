function outputFile = package_toolbox(outputFile)
root = fileparts(mfilename('fullpath'));
shared = fullfile(fileparts(root), 'matlab-octave-core', '+praxo');
packageVersion = strtrim(fileread(fullfile(root, 'VERSION')));
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(fileparts(shared));
run_tests();
testedRelease = ['R' version('-release')];
architecture = computer('arch');
stage = fullfile(root, 'build', 'matlab-package');
if exist(stage, 'dir')
    rmdir(stage, 's');
end
mkdir(stage);
copyfile(shared, fullfile(stage, '+praxo'));
copyfile(fullfile(root, 'README.md'), stage);
copyfile(fullfile(root, 'LICENSE'), stage);
copyfile(fullfile(root, 'toolbox-image.png'), stage);
if nargin < 1
    outputFile = fullfile(root, sprintf('praxo-core-%s.mltbx', packageVersion));
end
opts = matlab.addons.toolbox.ToolboxOptions(stage, ...
    'af9bcb16-1195-4766-a227-1bfcc127a524');
opts.ToolboxName = 'PRAXO-CORE';
try
    opts.PackageName = 'praxo_core';
catch
end
try
    opts.Tags = ["agent", "agent-framework", "llm", "ai", ...
        "tool-calling", "openai-compatible", "memory", "policy", ...
        "middleware", "checkpoint", "sandbox", "mit"];
catch
end
opts.ToolboxVersion = packageVersion;
opts.MinimumMatlabRelease = testedRelease;
opts.MaximumMatlabRelease = testedRelease;
platforms = fieldnames(opts.SupportedPlatforms);
for i = 1:numel(platforms)
    opts.SupportedPlatforms.(platforms{i}) = false;
end
switch architecture
    case 'win64'
        opts.SupportedPlatforms.Win64 = true;
    case 'glnxa64'
        opts.SupportedPlatforms.Glnxa64 = true;
    case 'maca64'
        opts.SupportedPlatforms.Mac = true;
    otherwise
        error('praxo:platform', 'No verified packaging metadata for %s', architecture);
end
opts.Summary = 'Embeddable MIT-licensed agent framework for MATLAB';
opts.AuthorName = 'AxisVela';
opts.AuthorEmail = 'releases@axisvela.com';
opts.AuthorCompany = 'AxisVela';
opts.ToolboxMatlabPath = '.';
opts.ToolboxImageFile = fullfile(stage, 'toolbox-image.png');
opts.ToolboxFiles = {'+praxo', 'README.md', 'LICENSE', 'toolbox-image.png'};
opts.OutputFile = outputFile;
matlab.addons.toolbox.packageToolbox(opts);
end
