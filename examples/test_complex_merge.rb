#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "jsonc-merge", path: "/home/pboling/src/kettle-rb/ast-merge/vendor/jsonc-merge"
  gem "ast-merge", path: "/home/pboling/src/kettle-rb/ast-merge"
  gem "tree_haver", path: "/home/pboling/src/kettle-rb/ast-merge/vendor/tree_haver"
  gem "ruby_tree_sitter", path: File.expand_path("../../ruby-tree-sitter", __dir__), require: "tree_sitter", platform: :mri
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
