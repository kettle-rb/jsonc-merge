#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick test of nested object merging

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "jsonc-merge", path: File.expand_path("..", __dir__)
end

require "jsonc/merge"
require "json"

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

puts "Template:"
puts template
puts

puts "Destination:"
puts dest
puts

merger = Jsonc::Merge::SmartMerger.new(template, dest, add_template_only_nodes: true, preference: :destination)
result = merger.merge

puts "Merged Result:"
puts result
puts

begin
  parsed = JSON.parse(result)
  puts "✓ Valid JSON!"
  puts
  puts "Root keys: #{parsed.keys.inspect}"
  puts "Name: #{parsed["name"].inspect}"
  puts
  puts "Config keys: #{parsed["config"].keys.sort.inspect}"
  puts "Config host: #{parsed["config"]["host"].inspect}"
  puts "Config port: #{parsed["config"]["port"].inspect}"
  puts "Config newSetting: #{parsed["config"]["newSetting"].inspect}"
  puts
  puts "Has newSetting from template? #{parsed["config"].key?("newSetting")}"
  puts "Expected: true"
  puts "PASS!" if parsed["config"]["newSetting"] == true && parsed["config"]["host"] == "production.com"
rescue JSON::ParserError => e
  puts "✗ Invalid JSON: #{e.message}"
  puts "Result was:"
  puts result
end
