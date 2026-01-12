#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to investigate Java backend behavior with jtreesitter
#
# Usage (from jsonc-merge root directory):
#   jruby debug_java_backend.rb

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "ast-merge", path: File.expand_path("../../../../", __dir__)
  gem "jsonc-merge", path: File.expand_path("..", __dir__)
  gem "tree_haver", path: File.expand_path("../tree_haver", __dir__)
end

require "jsonc/merge"

puts "=" * 80
puts "JRuby/Java Backend Debug Script for jsonc-merge"
puts "=" * 80
puts "Ruby Engine: #{RUBY_ENGINE}"
puts "Ruby Version: #{RUBY_VERSION}"
puts

unless RUBY_ENGINE == "jruby"
  puts "ERROR: This script must be run with JRuby!"
  puts "Usage: jruby debug_java_backend.rb"
  exit 1
end

puts "Environment Variables:"
puts "  TREE_SITTER_JAVA_JARS_DIR: #{ENV["TREE_SITTER_JAVA_JARS_DIR"].inspect}"
puts "  TREE_SITTER_RUNTIME_LIB:   #{ENV["TREE_SITTER_RUNTIME_LIB"].inspect}"
puts "  TREE_SITTER_JSONC_PATH:    #{ENV["TREE_SITTER_JSONC_PATH"].inspect}"
puts

# Check Java backend availability
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
puts "  Java backend available?: #{begin
  TreeHaver::Backends::Java.available?
rescue
  false
end}"
puts

# Test if JSONC grammar can be loaded
puts "=" * 80
puts "0. Grammar Loading Test"
puts "=" * 80

jsonc_path = ENV["TREE_SITTER_JSONC_PATH"]
if jsonc_path && File.exist?(jsonc_path)
  puts "JSONC grammar path: #{jsonc_path}"
  puts "File exists: #{File.exist?(jsonc_path)}"
  puts "File size: #{File.size(jsonc_path)} bytes"
  puts

  begin
    TreeHaver.with_backend(:java) do
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
    puts "Please ensure tree-sitter-jsonc is installed and TREE_SITTER_JSONC_PATH is set."
    exit(1)
  end
else
  puts "✗ TREE_SITTER_JSONC_PATH not set or file doesn't exist"
  puts "  Value: #{jsonc_path.inspect}"
  puts
  puts "Please run: ts-grammar-action install jsonc"
  puts "Or set TREE_SITTER_JSONC_PATH to point to libtree-sitter-jsonc.so"
  exit 1
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

analysis = Jsonc::Merge::FileAnalysis.new(valid_json)
puts "Valid: #{analysis.valid?}"
puts "Errors: #{analysis.errors.inspect}"
puts "AST: #{analysis.instance_variable_get(:@ast).inspect}"
puts "Root node: #{analysis.root_node.inspect}"
puts

if analysis.root_node
  root = analysis.root_node
  puts "Root node type: #{root.type}"
  puts "Root node has each?: #{root.instance_variable_get(:@node).respond_to?(:each)}"
  puts

  # Get the object node
  obj = analysis.root_object
  if obj
    puts "Object node: #{obj.type}"
    puts "Object pairs count: #{obj.pairs.size}"
    puts

    # Examine first pair
    if obj.pairs.any?
      pair = obj.pairs.first
      puts "First pair type: #{pair.type}"
      puts "First pair node: #{pair.instance_variable_get(:@node).inspect}"
      puts

      # Check if child_by_field_name is available
      pair_node = pair.instance_variable_get(:@node)
      puts "Pair node responds to child_by_field_name?: #{pair_node.respond_to?(:child_by_field_name)}"

      if pair_node.respond_to?(:child_by_field_name)
        key_node = pair_node.child_by_field_name("key")
        value_node = pair_node.child_by_field_name("value")
        puts "Key node via field: #{key_node.inspect}"
        puts "Value node via field: #{value_node.inspect}"
      else
        puts "child_by_field_name NOT AVAILABLE - must use iteration"
      end
      puts

      # Examine children
      puts "Pair children:"
      pair_node.each_with_index do |child, idx|
        puts "  [#{idx}] type=#{child.type.to_s.inspect}, text=#{child.to_s.inspect}"
      end
      puts

      # Test our methods
      puts "pair.key_name: #{pair.key_name.inspect}"
      puts "pair.value_node: #{pair.value_node.inspect}"
      puts
    end
  end
end

puts "=" * 80
puts "2. Testing FileAnalysis with Invalid JSON"
puts "=" * 80

analysis = Jsonc::Merge::FileAnalysis.new(invalid_json)
puts "Valid: #{analysis.valid?}"
puts "Errors: #{analysis.errors.inspect}"
puts "AST: #{analysis.instance_variable_get(:@ast).inspect}"

if analysis.instance_variable_get(:@ast)
  ast = analysis.instance_variable_get(:@ast)
  root = ast.root_node
  puts "Root node: #{root.inspect}"
  puts "Root node type: #{root.type}"
  puts "Root has has_error? method?: #{root.respond_to?(:has_error?)}"
  if root.respond_to?(:has_error?)
    puts "Root has_error?: #{root.has_error?}"
  end
  puts

  puts "Scanning for ERROR nodes:"
  error_count = 0
  root.each do |child|
    child_type = child.type.to_s
    puts "  Child type: #{child_type.inspect}"
    error_count += 1 if child_type == "ERROR"
  end
  puts "ERROR nodes found: #{error_count}"
end
puts

puts "=" * 80
puts "3. Testing SmartMerger with add_template_only_nodes"
puts "=" * 80

merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json, add_template_only_nodes: true)
puts "Template analysis valid?: #{merger.template_analysis.valid?}"
puts "Destination analysis valid?: #{merger.dest_analysis.valid?}"
puts

puts "Template root_object:"
template_obj = merger.template_analysis.root_object
if template_obj
  puts "  Type: #{template_obj.type}"
  puts "  Container?: #{template_obj.container?}"
  puts "  Mergeable children: #{template_obj.mergeable_children.size}"
  puts "  Pairs:"
  template_obj.pairs.each do |pair|
    sig = merger.template_analysis.generate_signature(pair)
    puts "    #{pair.key_name.inspect} => signature: #{sig.inspect}"
  end
end
puts

puts "Destination root_object:"
dest_obj = merger.dest_analysis.root_object
if dest_obj
  puts "  Type: #{dest_obj.type}"
  puts "  Container?: #{dest_obj.container?}"
  puts "  Mergeable children: #{dest_obj.mergeable_children.size}"
  puts "  Pairs:"
  dest_obj.pairs.each do |pair|
    sig = merger.dest_analysis.generate_signature(pair)
    puts "    #{pair.key_name.inspect} => signature: #{sig.inspect}"
  end
end
puts

puts "Template statements (top-level):"
merger.template_analysis.statements.each_with_index do |stmt, idx|
  puts "  [#{idx}] type=#{stmt.type}, container?=#{stmt.container?}, sig=#{merger.template_analysis.generate_signature(stmt).inspect}"
end
puts

puts "Destination statements (top-level):"
merger.dest_analysis.statements.each_with_index do |stmt, idx|
  puts "  [#{idx}] type=#{stmt.type}, container?=#{stmt.container?}, sig=#{merger.dest_analysis.generate_signature(stmt).inspect}"
end
puts

puts "Performing merge..."
puts "Merge options: #{merger.options.inspect}"
puts "Add template only nodes: #{merger.instance_variable_get(:@add_template_only_nodes)}"
puts

merge_result = merger.merge_result
puts "MergeResult class: #{merge_result.class}"
puts "MergeResult valid?: #{merge_result.respond_to?(:valid?) ? merge_result.valid? : "N/A"}"
puts "MergeResult line_count: #{begin
  merge_result.line_count
rescue
  "N/A"
end}"
puts

if merge_result.respond_to?(:decisions)
  puts "MergeResult decisions:"
  merge_result.decisions.each do |decision, count|
    puts "  #{decision}: #{count}"
  end
  puts
end

if merge_result.respond_to?(:lines)
  puts "Result lines (#{merge_result.lines.size}):"
  merge_result.lines.each_with_index do |line, idx|
    puts "  [#{idx}] #{line.inspect}"
  end
  puts
end

result = merge_result.to_s
puts "Final merged string (to_s):"
puts result
puts
puts "String length: #{result.length}"
puts "Line count: #{result.lines.count}"
puts

puts "Expected: Single JSON object with 'name' from destination and 'newField' from template"
puts "Checking if 'newField' is present: #{result.include?("newField")}"
puts "Checking if 'destination' is present: #{result.include?("destination")}"
puts

puts "=" * 80
puts "4. Backend Information"
puts "=" * 80

puts "TreeHaver backend: #{begin
  TreeHaver.backend
rescue
  "N/A"
end}"
puts "TreeHaver effective_backend: #{begin
  TreeHaver.effective_backend
rescue
  "N/A"
end}"

# Try to get more info about the parser
begin
  parser = TreeHaver.parser_for(:jsonc)
  puts "Parser class: #{parser.class}"
  puts "Parser language: #{begin
    parser.language
  rescue
    "N/A"
  end}"
rescue => e
  puts "Error getting parser: #{e.message}"
end

puts
puts "=" * 80
puts "SUMMARY & NEXT STEPS"
puts "=" * 80
puts

if analysis.valid? && merger.template_analysis.valid?
  puts "✓ Basic functionality is working!"
  puts
  puts "If tests are still failing, the issue is likely in:"
  puts "  1. How tree-sitter nodes expose their fields (child_by_field_name)"
  puts "  2. How ERROR nodes are detected (has_error?)"
  puts "  3. Backend-specific API differences"
  puts
  puts "Check the output above for:"
  puts "  - Does 'child_by_field_name' exist?"
  puts "  - Can we access key/value from pair nodes?"
  puts "  - Are signatures being generated correctly?"
  puts "  - Are ERROR nodes detected for invalid JSON?"
else
  puts "✗ Issues detected during testing"
  puts
  puts "Review the output above to identify the problem."
  puts "Common issues:"
  puts "  1. JSONC grammar not loaded"
  puts "  2. Java backend not properly initialized"
  puts "  3. Missing JARs or native libraries"
end

puts
puts "Setup check:"
puts "  1. TREE_SITTER_JAVA_JARS_DIR set? #{!ENV["TREE_SITTER_JAVA_JARS_DIR"].nil?}"
puts "  2. TREE_SITTER_JSONC_PATH set? #{!ENV["TREE_SITTER_JSONC_PATH"].nil?}"
puts "  3. Java backend available? #{begin
  TreeHaver::Backends::Java.available?
rescue
  false
end}"
puts
