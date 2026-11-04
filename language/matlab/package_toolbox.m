function outputFile = package_toolbox(outputFile)
root = fileparts(mfilename('fullpath'));
version = strtrim(fileread(fullfile(root, 'VERSION')));
if nargin < 1
    outputFile = fullfile(root, sprintf('praxo-core-%s.mltbx', version));
end
opts = matlab.addons.toolbox.ToolboxOptions(root, ...
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
opts.Summary = 'Embeddable MIT-licensed agent framework for MATLAB and Octave';
opts.AuthorName = 'AxisVela';
opts.AuthorEmail = 'releases@axisvela.com';
opts.AuthorCompany = 'AxisVela';
opts.ToolboxMatlabPath = '.';
opts.ToolboxFiles = {'+praxo', 'README.md', 'LICENSE', 'run_tests.m'};
opts.OutputFile = outputFile;
matlab.addons.toolbox.packageToolbox(opts);
end
