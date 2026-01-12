#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick test of comma functionality

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "jsonc-merge", path: File.expand_path("..", __dir__)
end

require "jsonc/merge"
require "json"

template = '{"name": "template", "version": "1.0.0"}'
dest = '{"name": "destination", "port": 8080}'

puts "Template: #{template}"
puts "Dest: #{dest}"
puts

merger = Jsonc::Merge::SmartMerger.new(template, dest, add_template_only_nodes: true)
result = merger.merge

puts "Result:"
puts result
puts

begin
  parsed = JSON.parse(result)
  puts "✓ Valid JSON!"
  puts "Keys: #{parsed.keys.inspect}"
  puts "Values: #{parsed.inspect}"
rescue JSON::ParserError => e
  puts "✗ Invalid JSON: #{e.message}"
  exit(1)
end
