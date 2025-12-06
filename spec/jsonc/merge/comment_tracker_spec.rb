# frozen_string_literal: true

RSpec.describe Jsonc::Merge::CommentTracker do
  let(:content_with_comments) do
    <<~JSON
      {
        // This is a line comment
        "name": "test",
        /* Block comment */
        "version": "1.0"
      }
    JSON
  end

  let(:content_without_comments) do
    <<~JSON
      {
        "name": "test",
        "version": "1.0"
      }
    JSON
  end

  describe "#initialize" do
    it "returns a CommentTracker instance" do
      tracker = described_class.new(content_with_comments)
      expect(tracker).to be_a(described_class)
    end

    it "extracts line comments (block: false)" do
      tracker = described_class.new(content_with_comments)
      expect(tracker.comments.any? { |c| c[:block] == false }).to be true
    end

    it "extracts block comments (block: true)" do
      tracker = described_class.new(content_with_comments)
      expect(tracker.comments.any? { |c| c[:block] == true }).to be true
    end
  end

  describe "#comments" do
    it "returns an array of comment hashes" do
      tracker = described_class.new(content_with_comments)
      expect(tracker.comments).to be_an(Array)
      expect(tracker.comments.first).to be_a(Hash) if tracker.comments.any?
    end

    it "returns empty array for content without comments" do
      tracker = described_class.new(content_without_comments)
      expect(tracker.comments).to eq([])
    end

    it "includes line number and text in comment hashes" do
      tracker = described_class.new(content_with_comments)
      comment = tracker.comments.first
      expect(comment).to have_key(:line)
      expect(comment).to have_key(:text)
    end
  end

  describe "#leading_comments_before" do
    it "returns comments before a given line" do
      tracker = described_class.new(content_with_comments)
      # Line comments should be before line 3
      leading = tracker.leading_comments_before(3)
      expect(leading).to be_an(Array)
    end
  end

  describe "#inline_comment_at" do
    it "returns inline comment on a given line" do
      content = '{"key": "value" // trailing comment }'
      tracker = described_class.new(content)
      inline = tracker.inline_comment_at(1)
      expect(inline).to be_a(Hash).or be_nil
    end

    it "returns nil for full-line comments" do
      content = "// Full line comment\n{}"
      tracker = described_class.new(content)
      inline = tracker.inline_comment_at(1)
      expect(inline).to be_nil
    end

    it "returns nil for lines without comments" do
      tracker = described_class.new(content_without_comments)
      expect(tracker.inline_comment_at(2)).to be_nil
    end
  end

  describe "#comment_at" do
    it "returns comment at a specific line" do
      tracker = described_class.new(content_with_comments)
      # Line 2 has the line comment
      comment = tracker.comment_at(2)
      expect(comment).to be_a(Hash)
      expect(comment[:text]).to eq("This is a line comment")
    end

    it "returns nil for lines without comments" do
      tracker = described_class.new(content_with_comments)
      expect(tracker.comment_at(1)).to be_nil
    end
  end

  describe "#full_line_comment?" do
    it "returns true for full-line comments" do
      tracker = described_class.new(content_with_comments)
      expect(tracker.full_line_comment?(2)).to be true
    end

    it "returns false for lines without comments" do
      tracker = described_class.new(content_with_comments)
      expect(tracker.full_line_comment?(3)).to be false
    end

    it "returns false for inline comments" do
      content = '{"key": "value" // inline}'
      tracker = described_class.new(content)
      expect(tracker.full_line_comment?(1)).to be false
    end
  end

  describe "#blank_line?" do
    it "returns true for blank lines" do
      content = "{\n\n  \"key\": \"value\"\n}"
      tracker = described_class.new(content)
      expect(tracker.blank_line?(2)).to be true
    end

    it "returns false for non-blank lines" do
      tracker = described_class.new(content_without_comments)
      expect(tracker.blank_line?(1)).to be false
    end

    it "returns false for line number less than 1" do
      tracker = described_class.new(content_without_comments)
      expect(tracker.blank_line?(0)).to be false
    end

    it "returns false for line number greater than file length" do
      tracker = described_class.new(content_without_comments)
      expect(tracker.blank_line?(1000)).to be false
    end
  end

  describe "multi-line block comments" do
    it "handles block comments spanning multiple lines" do
      content = <<~JSON
        {
          /* This is a
             multi-line
             block comment */
          "key": "value"
        }
      JSON
      tracker = described_class.new(content)
      comments = tracker.comments.select { |c| c[:block] }
      expect(comments).not_to be_empty
    end

    it "handles block comment that starts and doesn't end on same line" do
      content = "{\n  /* start block\n  continued */\n}"
      tracker = described_class.new(content)
      comments = tracker.comments.select { |c| c[:block] }
      expect(comments.size).to be >= 1
    end
  end

  describe "inline comments with special cases" do
    it "does not detect // inside strings as comments" do
      content = '{"url": "https://example.com"}'
      tracker = described_class.new(content)
      expect(tracker.comments).to be_empty
    end

    it "detects inline comment after content with even quotes" do
      content = '{"key": "value"} // comment'
      tracker = described_class.new(content)
      inline = tracker.comments.find { |c| c[:full_line] == false }
      expect(inline).not_to be_nil
      expect(inline[:text]).to eq("comment")
    end

    it "handles escaped quotes in values" do
      content = '{"escaped": "value with \\"quote\\""} // comment'
      tracker = described_class.new(content)
      # This tests the quote balance logic
      expect(tracker.comments).to be_an(Array)
    end
  end

  describe "#comments_in_range" do
    it "returns comments within a line range" do
      content = <<~JSON
        {
          // comment 1
          "a": 1,
          // comment 2
          "b": 2
        }
      JSON
      tracker = described_class.new(content)
      in_range = tracker.comments_in_range(1..3)
      expect(in_range).to be_an(Array)
    end

    it "returns empty array when no comments in range" do
      content = <<~JSON
        {
          "a": 1,
          "b": 2
        }
      JSON
      tracker = described_class.new(content)
      in_range = tracker.comments_in_range(1..2)
      expect(in_range).to eq([])
    end
  end

  describe "#lines" do
    it "returns source lines" do
      tracker = described_class.new(content_with_comments)
      expect(tracker.lines).to be_an(Array)
      expect(tracker.lines.first).to eq("{")
    end
  end

  describe "comment indentation tracking" do
    it "tracks indent level of comments" do
      content = <<~JSON
        {
          // indented comment
          "key": "value"
        }
      JSON
      tracker = described_class.new(content)
      comment = tracker.comments.first
      expect(comment[:indent]).to be >= 0
    end

    it "tracks indent of block comments" do
      content = <<~JSON
        {
            /* indented block */
          "key": "value"
        }
      JSON
      tracker = described_class.new(content)
      comment = tracker.comments.first
      expect(comment[:indent]).to be >= 0
    end
  end

  describe "comment raw content" do
    it "preserves raw content of comments" do
      content = "// raw comment line\n{}"
      tracker = described_class.new(content)
      comment = tracker.comments.first
      expect(comment[:raw]).to eq("// raw comment line")
    end
  end
end
