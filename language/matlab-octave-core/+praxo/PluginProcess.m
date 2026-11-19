classdef PluginProcess < handle
    properties (SetAccess = private)
        active = false
    end
    properties (Access = private)
        process
        reader
        writer
        pluginId
        token
        sequence = 0
    end
    methods
        function self = PluginProcess(config)
            if ~usejava('jvm')
                error('praxo:plugin', 'A Java runtime is required');
            end
            if ~isstruct(config) || ~isfield(config, 'plugin_id') || ...
                    ~isfield(config, 'path') || isempty(config.plugin_id) || isempty(config.path)
                error('praxo:plugin', 'plugin_id and path are required');
            end
            startTimeout = 10;
            if isfield(config, 'start_timeout')
                startTimeout = config.start_timeout;
            end
            self.checkTimeout(startTimeout);
            self.pluginId = config.plugin_id;
            uuid = javaMethod('randomUUID', 'java.util.UUID');
            self.token = char(uuid.toString());
            if isfield(config, 'token') && ~isempty(config.token)
                self.token = config.token;
            end
            args = {};
            if isfield(config, 'args')
                args = config.args;
            end
            command = javaArray('java.lang.String', numel(args) + 1);
            command(1) = javaObject('java.lang.String', config.path);
            for i = 1:numel(args)
                command(i + 1) = javaObject('java.lang.String', args{i});
            end
            builder = javaObject('java.lang.ProcessBuilder', command);
            environment = builder.environment();
            values = javaArray('java.lang.Object', 2);
            values(1) = javaObject('java.lang.String', 'PRAXOVELA_PLUGIN_TOKEN');
            values(2) = javaObject('java.lang.String', self.token);
            statement = javaObject('java.beans.Statement', environment, 'put', values);
            statement.execute();
            redirect = java_get_null_redirect();
            builder.redirectError(redirect);
            self.process = builder.start();
            try
                self.reader = javaObject('java.io.BufferedReader', ...
                    javaObject('java.io.InputStreamReader', ...
                    self.process.getInputStream(), 'UTF-8'));
                self.writer = javaObject('java.io.OutputStreamWriter', ...
                    self.process.getOutputStream(), 'UTF-8');
                self.call('host.control', 'health', '', startTimeout);
                self.active = true;
            catch failure
                self.terminate();
                rethrow(failure);
            end
        end
        function result = invoke(self, service, method, payload, timeout)
            if ~self.active
                error('praxo:plugin', 'plugin: host is not active');
            end
            if nargin < 5
                timeout = 30;
            end
            self.checkTimeout(timeout);
            try
                result = self.call(service, method, payload, timeout);
            catch failure
                if ~strcmp(failure.identifier, 'praxo:pluginCall')
                    self.terminate();
                end
                rethrow(failure);
            end
        end
        function stop(self)
            if isempty(self.process)
                return;
            end
            if self.active
                try
                    self.call('host.control', 'shutdown', '', 1);
                    unit = javaMethod('valueOf', 'java.util.concurrent.TimeUnit', 'MILLISECONDS');
                    self.process.waitFor(int64(1000), unit);
                catch
                end
            end
            self.terminate();
        end
        function delete(self)
            self.stop();
        end
    end
    methods (Access = private)
        function checkTimeout(~, timeout)
            if ~isnumeric(timeout) || ~isscalar(timeout) || ...
                    ~isreal(timeout) || ~isfinite(timeout) || timeout <= 0
                error('praxo:plugin', 'timeout must be a positive finite number');
            end
        end
        function terminate(self)
            self.active = false;
            process = self.process;
            reader = self.reader;
            writer = self.writer;
            self.process = [];
            self.reader = [];
            self.writer = [];
            if ~isempty(process)
                try
                    if process.isAlive()
                        process.destroyForcibly();
                    end
                    unit = javaMethod('valueOf', 'java.util.concurrent.TimeUnit', 'MILLISECONDS');
                    process.waitFor(int64(1000), unit);
                catch
                end
            end
            if ~isempty(reader)
                try
                    reader.close();
                catch
                end
            end
            if ~isempty(writer)
                try
                    writer.close();
                catch
                end
            end
        end
        function result = call(self, service, method, payload, timeout)
            self.sequence = self.sequence + 1;
            id = sprintf('req-%d', self.sequence);
            encoder = javaMethod('getEncoder', 'java.util.Base64');
            encoded = '';
            if ~isempty(payload)
                text = javaObject('java.lang.String', payload);
                encoded = char(encoder.encodeToString(text.getBytes('UTF-8')));
            end
            request = struct('id', id, 'version', 1, ...
                'plugin_id', self.pluginId, 'service', service, ...
                'method', method, 'token', self.token, 'payload', encoded);
            self.writer.write([jsonencode(request) char(10)]);
            self.writer.flush();
            line = '';
            started = tic;
            while true
                if toc(started) >= timeout
                    error('praxo:pluginTimeout', 'plugin: response timed out');
                end
                if self.reader.ready()
                    ch = self.reader.read();
                    if ch < 0
                        error('praxo:plugin', 'plugin: output closed');
                    end
                    if ch == 10
                        break;
                    end
                    line(end + 1) = char(ch);
                    if numel(line) > 8388608
                        error('praxo:plugin', 'plugin: frame too large');
                    end
                elseif ~self.process.isAlive()
                    error('praxo:plugin', 'plugin: process exited');
                else
                    pause(0.005);
                end
            end
            response = jsondecode(line);
            if ~isstruct(response) || ~isscalar(response) || ...
                    ~isfield(response, 'id') || ~ischar(response.id) || ...
                    ~strcmp(response.id, id) || ~isfield(response, 'version') || ...
                    ~isequal(response.version, 1) || ~isfield(response, 'ok') || ...
                    ~islogical(response.ok) || ~isscalar(response.ok)
                error('praxo:plugin', 'plugin: invalid response envelope');
            end
            if ~response.ok
                if ~isfield(response, 'code') || ~ischar(response.code)
                    error('praxo:plugin', 'plugin: invalid error envelope');
                end
                error('praxo:pluginCall', '%s', response.code);
            end
            result = '';
            if isfield(response, 'payload') && ~isempty(response.payload)
                if ~ischar(response.payload)
                    error('praxo:plugin', 'plugin: invalid payload');
                end
                decoder = javaMethod('getDecoder', 'java.util.Base64');
                bytes = decoder.decode(response.payload);
                result = char(javaObject('java.lang.String', bytes, 'UTF-8'));
            end
        end
    end
end

function redirect = java_get_null_redirect()
if ispc
    path = 'NUL';
else
    path = '/dev/null';
end
file = javaObject('java.io.File', path);
redirect = javaMethod('to', 'java.lang.ProcessBuilder$Redirect', file);
end
