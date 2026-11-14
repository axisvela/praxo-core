chunks = {'status: ', 'green'};
received = {};
output = '';
for i = 1:numel(chunks)
    output = [output chunks{i}];
    received{end + 1} = chunks{i};
end
assert(strcmp(output, 'status: green'));
assert(strcmp(strjoin(received, ''), output));
disp('MATLAB streaming example passed');
