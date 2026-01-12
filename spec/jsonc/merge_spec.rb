# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jsonc::Merge do
  it "has a version number" do
    expect(Jsonc::Merge::VERSION).not_to be_nil
  end

  describe Jsonc::Merge::Error do
    it "inherits from Ast::Merge::Error" do
      expect(described_class.superclass).to eq(Ast::Merge::Error)
    end

    it "can be instantiated with a message" do
      error = described_class.new("test error")
      expect(error.message).to eq("test error")
    end
  end

  describe Jsonc::Merge::ParseError do
    it "inherits from Ast::Merge::ParseError" do
      expect(described_class.superclass).to eq(Ast::Merge::ParseError)
    end

    it "can be instantiated with no arguments" do
      error = described_class.new
      expect(error).to be_a(described_class)
      expect(error.errors).to eq([])
      expect(error.content).to be_nil
    end

    it "can be instantiated with a message" do
      error = described_class.new("custom message")
      expect(error.message).to eq("custom message")
    end

    it "can be instantiated with content" do
      error = described_class.new(content: '{"invalid": }')
      expect(error.content).to eq('{"invalid": }')
    end

    it "can be instantiated with errors array" do
      errors = [StandardError.new("error 1"), StandardError.new("error 2")]
      error = described_class.new(errors: errors)
      expect(error.errors).to eq(errors)
    end

    it "can be instantiated with all arguments" do
      errors = [StandardError.new("parse error")]
      error = described_class.new("failed to parse", content: '{"bad": }', errors: errors)
      expect(error.message).to eq("failed to parse")
      expect(error.content).to eq('{"bad": }')
      expect(error.errors).to eq(errors)
    end
  end

  describe Jsonc::Merge::TemplateParseError do
    it "inherits from Jsonc::Merge::ParseError" do
      expect(described_class.superclass).to eq(Jsonc::Merge::ParseError)
    end

    it "can be instantiated" do
      error = described_class.new("template error", content: '{"bad"}')
      expect(error.message).to eq("template error")
      expect(error.content).to eq('{"bad"}')
    end
  end

  describe Jsonc::Merge::DestinationParseError do
    it "inherits from Jsonc::Merge::ParseError" do
      expect(described_class.superclass).to eq(Jsonc::Merge::ParseError)
    end

    it "can be instantiated" do
      error = described_class.new("destination error", content: '{"bad"}')
      expect(error.message).to eq("destination error")
      expect(error.content).to eq('{"bad"}')
    end
  end
end
