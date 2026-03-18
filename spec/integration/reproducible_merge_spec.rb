# frozen_string_literal: true

require "spec_helper"
require "ast/merge/rspec/shared_examples"

RSpec.describe "JSONC reproducible merge", :jsonc_grammar do
  let(:fixtures_path) { File.expand_path("../fixtures/reproducible", __dir__) }
  let(:merger_class) { Jsonc::Merge::SmartMerger }
  let(:file_extension) { "jsonc" }

  describe "comment-heavy recursive scenarios" do
    context "when nested object destination docs and inline comments survive template-preferred updates" do
      it_behaves_like "a reproducible merge", "01_nested_object_comment_block_template_preference", {
        preference: :template,
        add_template_only_nodes: true,
      }
    end

    context "when keyed arrays of objects preserve destination comments during recursive additions" do
      it_behaves_like "a reproducible merge", "02_recursive_keyed_array_object_comments", {
        preference: :template,
        add_template_only_nodes: true,
      }
    end

    context "when removed destination-only array items promote their comments safely" do
      it_behaves_like "a reproducible merge", "03_removed_array_item_comment_promotion", {
        remove_template_missing_nodes: true,
      }
    end

    context "when matched container comments differ only by whitespace they are still preserved" do
      it_behaves_like "a reproducible merge", "04_devcontainer_whitespace_only_comment_preservation", {
        preference: :template,
        add_template_only_nodes: true,
      }
    end
  end
end
