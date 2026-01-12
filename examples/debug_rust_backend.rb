#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to investigate Rust backend behavior with tree_stump
#
# Usage (from jsonc-merge root directory):
#   ruby examples/debug_rust_backend.rb

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "ast-merge", path: File.expand_path("../../../../", __dir__)
  gem "jsonc-merge", path: File.expand_path("..", __dir__)
  gem "tree_haver", path: File.expand_path("../../tree_haver", __dir__)
  gem "tree_stump", path: File.expand_path("../../tree_stump", __dir__), platform: :mri
end

require "jsonc/merge"

puts "=" * 80
puts "Rust Backend Debug Script for jsonc-merge"
puts "=" * 80
puts "Ruby Engine: #{RUBY_ENGINE}"
puts "Ruby Version: #{RUBY_VERSION}"
puts

puts "Environment Variables:"
puts "  TREE_SITTER_JSONC_PATH: #{ENV["TREE_SITTER_JSONC_PATH"].inspect}"
puts

# Check Rust backend availability
puts "TreeHaver Backend Status:"
puts "  Current backend: #{begin
  TreeHaver.backend
rescue
  "N/A"
end}"
puts "  Effective backend: #{begin
  TreeHaver.effective_backend
rescue
  "N/A"
end}"
puts "  Rust backend available?: #{begin
  TreeHaver::Backends::Rust.available?
rescue
  false
end}"
puts

# Test if JSONC grammar can be loaded
puts "=" * 80
puts "0. Grammar Loading Test"
puts "=" * 80

begin
  TreeHaver.with_backend(:rust) do
    parser = TreeHaver.parser_for(:jsonc)
    puts "✓ JSONC grammar loaded successfully!"
    puts "  Parser class: #{parser.class}"
    puts "  Parser language: #{begin
      parser.language
    rescue
      "N/A"
    end}"
  end
rescue => e
  puts "✗ Grammar loading failed!"
  puts "  Error class: #{e.class}"
  puts "  Error message: #{e.message}"
  puts
  puts "This script cannot continue without a working JSONC grammar."
  puts "Please ensure tree_stump gem is installed and tree-sitter-jsonc is available."
  exit(1)
end
puts

# Simple valid JSON
valid_json = '{"name": "test", "version": "1.0.0"}'

# Invalid JSON
invalid_json = '{ "unclosed": '

# JSON with template-only node
template_json = '{"name": "template", "newField": "value"}'
dest_json = '{"name": "destination"}'

puts "=" * 80
puts "1. Testing FileAnalysis with Valid JSON"
puts "=" * 80

TreeHaver.with_backend(:rust) do
  analysis = Jsonc::Merge::FileAnalysis.new(valid_json)
  puts "Valid: #{analysis.valid?}"
  puts "Errors: #{analysis.errors.inspect}"
  puts "Root node: #{analysis.root_node.inspect}"
  puts

  if analysis.root_node
    obj = analysis.root_object
    if obj
      puts "Object node: #{obj.type}"
      puts "Object pairs count: #{obj.pairs.size}"
      puts

      if obj.pairs.any?
        pair = obj.pairs.first
        puts "First pair type: #{pair.type}"

        pair_node = pair.instance_variable_get(:@node)
        puts "Pair node responds to child_by_field_name?: #{pair_node.respond_to?(:child_by_field_name)}"

        puts "pair.key_name: #{pair.key_name.inspect}"
        puts "pair.value_node: #{pair.value_node.inspect}"
        puts
      end
    end
  end
end

puts "=" * 80
puts "2. Testing FileAnalysis with Invalid JSON"
puts "=" * 80

TreeHaver.with_backend(:rust) do
  analysis = Jsonc::Merge::FileAnalysis.new(invalid_json)
  puts "Valid: #{analysis.valid?}"
  puts "Errors count: #{analysis.errors.size}"
  puts
end

puts "=" * 80
puts "3. Testing SmartMerger with add_template_only_nodes"
puts "=" * 80

TreeHaver.with_backend(:rust) do
  merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json, add_template_only_nodes: true)

  puts "Template statements (top-level):"
  merger.template_analysis.statements.each_with_index do |stmt, idx|
    sig = merger.template_analysis.generate_signature(stmt)
    puts "  [#{idx}] type=#{stmt.type}, container?=#{stmt.container?}, sig=#{sig.inspect}"
  end
  puts

  puts "Destination statements (top-level):"
  merger.dest_analysis.statements.each_with_index do |stmt, idx|
    sig = merger.dest_analysis.generate_signature(stmt)
    puts "  [#{idx}] type=#{stmt.type}, container?=#{stmt.container?}, sig=#{sig.inspect}"
  end
  puts

  puts "Signatures match?: #{merger.template_analysis.generate_signature(merger.template_analysis.statements.first) == merger.dest_analysis.generate_signature(merger.dest_analysis.statements.first)}"
  puts

  result = merger.merge
  puts "Final merged result:"
  puts result
  puts
  puts "Checking if 'newField' is present: #{result.include?("newField")}"
  puts "Checking if 'destination' is present: #{result.include?("destination")}"
end

puts
puts "=" * 80
puts "SUMMARY"
puts "=" * 80
puts "Rust backend test complete. Compare with other backends."
