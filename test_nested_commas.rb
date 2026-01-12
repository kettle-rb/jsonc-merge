#!/usr/bin/env ruby
# frozen_string_literal: true

# Test comma logic with nested objects

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "jsonc-merge", path: File.expand_path("..", __dir__)
end

require "jsonc/merge"
require "json"

puts "=" * 60
puts "Test 1: Simple merge with template-only fields"
puts "=" * 60

template = '{"a": 1, "b": 2, "c": 3}'
dest = '{"a": 10, "d": 4}'

merger = Jsonc::Merge::SmartMerger.new(template, dest, add_template_only_nodes: true)
result = merger.merge

puts "Result:"
puts result
puts

begin
  parsed = JSON.parse(result)
  puts "✓ Valid JSON!"
  puts "Keys: #{parsed.keys.sort}"
  puts "Expected: [\"a\", \"b\", \"c\", \"d\"]"
  puts "Match: #{parsed.keys.sort == ["a", "b", "c", "d"]}"
rescue JSON::ParserError => e
  puts "✗ Invalid JSON: #{e.message}"
end

puts
puts "=" * 60
puts "Test 2: Nested objects"
puts "=" * 60

template = JSON.generate({
  "name" => "template",
  "config" => {
    "host" => "localhost",
    "newSetting" => true,
  },
})

dest = JSON.generate({
  "name" => "destination",
  "config" => {
    "host" => "production.com",
    "port" => 443,
  },
})

merger = Jsonc::Merge::SmartMerger.new(template, dest, add_template_only_nodes: true)
result = merger.merge

puts "Result:"
puts result
puts

begin
  parsed = JSON.parse(result)
  puts "✓ Valid JSON!"
  puts "Root keys: #{parsed.keys}"
  puts "Config keys: #{parsed["config"].keys.sort}"
  puts "Has newSetting: #{parsed["config"].key?("newSetting")}"
rescue JSON::ParserError => e
  puts "✗ Invalid JSON: #{e.message}"
end
