#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick test of emitter-based merging

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "jsonc-merge", path: File.expand_path("..", __dir__)
end

require "jsonc/merge"
require "json"

puts "=" * 70
puts "Test 1: Simple merge"
puts "=" * 70

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
  puts "Keys: #{parsed.keys.sort}"

  if parsed.keys.sort == ["name", "port", "version"]
    puts "✓ All keys present!"
  else
    puts "✗ Missing keys. Expected: [name, port, version], Got: #{parsed.keys.sort}"
  end

  if parsed["name"] == "destination"
    puts "✓ Preference working!"
  else
    puts "✗ Preference not working. Expected: destination, Got: #{parsed["name"]}"
  end
rescue JSON::ParserError => e
  puts "✗ INVALID JSON: #{e.message}"
  puts "Result was:"
  result.lines.each_with_index do |line, idx|
    puts "  #{idx}: #{line}"
  end
  exit(1)
end

puts
puts "=" * 70
puts "Test 2: Nested merge"
puts "=" * 70

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

puts "Merging nested objects..."
merger = Jsonc::Merge::SmartMerger.new(template, dest, add_template_only_nodes: true, preference: :destination)
result = merger.merge

puts "Result:"
puts result
puts

begin
  parsed = JSON.parse(result)
  puts "✓ Valid JSON!"

  if parsed["config"]["newSetting"] == true
    puts "✓ Nested template-only field added!"
  else
    puts "✗ Missing nested template-only field"
  end

  if parsed["config"]["host"] == "production.com"
    puts "✓ Nested preference working!"
  else
    puts "✗ Nested preference not working"
  end

  puts
  puts "EMITTER INTEGRATION WORKING!" if parsed["config"]["newSetting"] == true
rescue JSON::ParserError => e
  puts "✗ INVALID JSON: #{e.message}"
  puts "Result was:"
  result.lines.each_with_index do |line, idx|
    puts "  #{idx}: #{line}"
  end
  exit(1)
end
