#!/usr/bin/env ruby
# frozen_string_literal: true

WORKSPACE_ROOT = File.expand_path("../..", __dir__)
ENV["KETTLE_RB_DEV"] = WORKSPACE_ROOT unless ENV.key?("KETTLE_RB_DEV")

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  require File.expand_path("nomono/lib/nomono/bundler", WORKSPACE_ROOT)

  eval_nomono_gems(
    gems: %w[jsonc-merge ast-merge tree_haver],
    prefix: "KETTLE_RB",
    path_env: "KETTLE_RB_DEV",
    vendored_gems_env: "VENDORED_GEMS",
    vendor_gem_dir_env: "VENDOR_GEM_DIR",
    debug_env: "KETTLE_DEV_DEBUG"
  )

  gem "ruby_tree_sitter", require: "tree_sitter", platform: :mri
end

complex_template = <<~JSON
  {
    "name": "template",
    "version": "2.0.0",
    "config": {
      "host": "production.com",
      "port": 443
    },
    "features": {
      "newFeature": true
    }
  }
JSON

complex_dest = <<~JSON
  {
    "name": "destination",
    "version": "1.0.0",
    "config": {
      "host": "localhost",
      "port": 8080,
      "timeout": 5000,
      "ssl": false
    }
  }
JSON

puts "=" * 80
puts "Testing Complex Nested Merge"
puts "=" * 80

merger = Jsonc::Merge::SmartMerger.new(
  complex_template,
  complex_dest,
  preference: :destination,
  add_template_only_nodes: true,
)

result = merger.merge

puts "\nMerged Result:"
puts result.to_json
puts "\n" + "=" * 80

# Try to parse it
begin
  parsed = JSON.parse(result.to_json)
  puts "✓ Valid JSON!"
  puts "Parsed: #{parsed.inspect}"
rescue JSON::ParserError => e
  puts "✗ Invalid JSON!"
  puts "Error: #{e.message}"
  puts "\nResult content (with line numbers):"
  result.to_json.lines.each_with_index do |line, i|
    puts "#{(i + 1).to_s.rjust(3)}: #{line}"
  end
end
