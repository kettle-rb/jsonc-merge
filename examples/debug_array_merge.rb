#!/usr/bin/env ruby
# frozen_string_literal: true

WORKSPACE_ROOT = File.expand_path("../..", __dir__)
ENV["KETTLE_RB_DEV"] = WORKSPACE_ROOT unless ENV.key?("KETTLE_RB_DEV")

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  require File.expand_path("nomono/lib/nomono/bundler", WORKSPACE_ROOT)

  eval_nomono_gems(
    gems: %w[ast-merge jsonc-merge tree_haver],
    prefix: "KETTLE_RB",
    path_env: "KETTLE_RB_DEV",
    vendored_gems_env: "VENDORED_GEMS",
    vendor_gem_dir_env: "VENDOR_GEM_DIR",
    debug_env: "KETTLE_DEV_DEBUG"
  )

  gem "ruby_tree_sitter", require: "tree_sitter", platform: :mri
end

require "jsonc/merge"
require "json"

template_json = '{"items": [1, 2, 3]}'
dest_json = '{"items": [4, 5]}'

puts "=" * 80
puts "Array Handling Test"
puts "=" * 80

TreeHaver.with_backend(:mri) do
  TreeHaver.parser_for(:jsonc)
  puts "✓ JSONC grammar loaded"
  puts

  merger = Jsonc::Merge::SmartMerger.new(
    template_json,
    dest_json,
    preference: :destination,
  )

  result = merger.merge

  puts "Merged JSON (with line numbers):"
  result.lines.each_with_index do |line, i|
    puts "#{(i + 1).to_s.rjust(3)}: #{line}"
  end

  puts "\n" + "=" * 80
  puts "Attempting to parse..."

  begin
    parsed = JSON.parse(result)
    puts "✓ SUCCESS: Valid JSON!"
    puts "items: #{parsed["items"].inspect}"
    puts "Expected: [4, 5]"
    puts "Match: #{parsed["items"] == [4, 5]}"
  rescue JSON::ParserError => e
    puts "✗ FAILURE: Invalid JSON!"
    puts "Error: #{e.message}"
  end
end

puts "=" * 80
