#!/usr/bin/env ruby

require 'fileutils'

ROOT = File.expand_path(__dir__)
REPO = File.expand_path('..', ROOT)
VERSION = File.read(File.join(ROOT, 'VERSION')).strip
SPEC = File.read(File.join(REPO, 'spec', 'SPEC_VERSION')).strip

entries = []
Dir.glob(File.join(ROOT, 'lib', 'praxo', '*.rb')).sort.each do |path|
  File.readlines(path, chomp: true).each do |line|
    stripped = line.strip
    if (match = stripped.match(/\A(module|class)\s+([A-Z]\w*)/))
      entries << "#{match[1]} #{match[2]}"
    elsif (match = stripped.match(/\Adef\s+(?:self\.)?([a-z_]\w*[!?]?)/))
      entries << "def #{match[1]}"
    end
  end
end
entries = entries.uniq.sort

content = [
  "# PRAXO-CORE Ruby API #{VERSION}",
  "# SPEC_VERSION #{SPEC}",
  '',
  *entries,
  ''
].join("\n")

target = File.join(ROOT, 'api', "#{VERSION}.txt")
if ARGV.include?('--check')
  unless File.exist?(target)
    warn "missing snapshot: #{target}"
    exit 1
  end
  unless File.read(target) == content
    warn "snapshot is stale: #{target}"
    exit 1
  end
  puts "snapshot is current: #{target}"
else
  FileUtils.mkdir_p(File.dirname(target))
  File.write(target, content)
  puts "wrote #{target}"
end
