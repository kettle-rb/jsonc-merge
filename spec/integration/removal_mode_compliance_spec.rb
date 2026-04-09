# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

require "spec_helper"
require "ast/merge/rspec/shared_examples"

RSpec.describe Jsonc::Merge::SmartMerger, :jsonc_grammar do
  it_behaves_like "Ast::Merge::RemovalModeCompliance" do
    let(:merger_class) { described_class }

    let(:removal_mode_leading_comments_case) do
      {
        template: <<~JSON,
          {
            "keep": 1,
            "tail": 3
          }
        JSON
        destination: <<~JSON,
          {
            "keep": 1,
            // Remove docs
            "remove": 2,
            "tail": 3
          }
        JSON
        expected: <<~JSON,
          {
            "keep": 1,
            // Remove docs
            "tail": 3
          }
        JSON
      }
    end

    let(:removal_mode_inline_comments_case) do
      {
        template: <<~JSON,
          {
            "keep": 1,
            "tail": 3
          }
        JSON
        destination: <<~JSON,
          {
            "keep": 1,
            "remove": 2, // remove inline
            "tail": 3
          }
        JSON
        expected: <<~JSON,
          {
            "keep": 1,
            // remove inline
            "tail": 3
          }
        JSON
      }
    end

    let(:removal_mode_separator_blank_line_case) do
      {
        template: <<~JSON,
          {
            "keep": 1,
            "tail": 3
          }
        JSON
        destination: <<~JSON,
          {
            "keep": 1,
            // Remove docs
            "remove": 2, // remove inline

            // trailing note
            "tail": 3
          }
        JSON
        expected: <<~JSON,
          {
            "keep": 1,
            // Remove docs
            // remove inline

            // trailing note
            "tail": 3
          }
        JSON
      }
    end

    let(:removal_mode_recursive_case) do
      fixture_dir = File.expand_path("../fixtures/reproducible/03_removed_array_item_comment_promotion", __dir__)

      {
        template: File.read(File.join(fixture_dir, "template.jsonc")),
        destination: File.read(File.join(fixture_dir, "destination.jsonc")),
        expected: File.read(File.join(fixture_dir, "result.jsonc")),
      }
    end
  end
end

# rubocop:enable RSpec/SpecFilePathFormat
