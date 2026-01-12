#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "ast-merge", path: File.expand_path("../../../../", __dir__)
  gem "jsonc-merge", path: File.expand_path("..", __dir__)
  gem "tree_haver", path: File.expand_path("../../tree_haver", __dir__)
  gem "ruby_tree_sitter", path: File.expand_path("../../ruby-tree-sitter", __dir__), require: "tree_sitter", platform: :mri
end

require "jsonc/merge"
require "json"

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
puts "Complex Nested Merge Test"
puts "=" * 80

TreeHaver.with_backend(:mri) do
  # Load the grammar first
  parser = TreeHaver.parser_for(:jsonc)
  puts "✓ JSONC grammar loaded: #{parser.class}"
  puts

  merger = Jsonc::Merge::SmartMerger.new(
    complex_template,
    complex_dest,
    preference: :destination,
    add_template_only_nodes: true,
  )

  result_obj = merger.merge_result
  result = result_obj.to_json

  puts "\nMerged JSON (with line numbers):"
  result.lines.each_with_index do |line, i|
    puts "#{(i + 1).to_s.rjust(3)}: #{line}"
  end

  puts "\n" + "=" * 80
  puts "Attempting to parse..."

  begin
    parsed = JSON.parse(result)
    puts "✓ SUCCESS: Valid JSON!"
    puts "Keys: #{parsed.keys.inspect}"
  rescue JSON::ParserError => e
    puts "✗ FAILURE: Invalid JSON!"
    puts "Error: #{e.message}"
  end
end

puts "=" * 80
