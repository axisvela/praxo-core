function outputFile = package_toolbox(outputFile)
root = fileparts(mfilename('fullpath'));
shared = fullfile(fileparts(root), 'matlab-octave-core', '+praxo');
version = strtrim(fileread(fullfile(root, 'VERSION')));
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
    outputFile = fullfile(root, sprintf('praxo-core-%s.mltbx', version));
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
opts.ToolboxVersion = version;
opts.MinimumMatlabRelease = 'R2020a';
opts.MaximumMatlabRelease = '';
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
