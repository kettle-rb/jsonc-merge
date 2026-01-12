# frozen_string_literal: true

module Jsonc
  module Merge
    # Wraps TreeHaver nodes with comment associations, line information, and signatures.
    # This provides a unified interface for working with JSONC (JSON with Comments) AST nodes during merging.
    #
    # Inherits common functionality from Ast::Merge::NodeWrapperBase:
    # - Source context (lines, source, comments)
    # - Line info extraction
    # - Basic methods: #type, #type?, #text, #content, #signature
    #
    # @example Basic usage
    #   parser = TreeHaver::Parser.new
    #   parser.language = TreeHaver::Language.jsonc
    #   tree = parser.parse(source)
    #   wrapper = NodeWrapper.new(tree.root_node, lines: source.lines, source: source)
    #   wrapper.signature # => [:object, ...]
    #
    # @see Ast::Merge::NodeWrapperBase
    class NodeWrapper < Ast::Merge::NodeWrapperBase
      # Check if this is a JSON object
      # @return [Boolean]
      def object?
        @node.type.to_s == "object"
      end

      # Check if this is a JSON array
      # @return [Boolean]
      def array?
        @node.type.to_s == "array"
      end

      # Check if this is a JSON string
      # @return [Boolean]
      def string?
        @node.type.to_s == "string"
      end

      # Check if this is a JSON number
      # @return [Boolean]
      def number?
        @node.type.to_s == "number"
      end

      # Check if this is a JSON boolean (true/false)
      # @return [Boolean]
      def boolean?
        %w[true false].include?(@node.type.to_s)
      end

      # Check if this is a JSON null
      # @return [Boolean]
      def null?
        @node.type.to_s == "null"
      end

      # Check if this is a key-value pair
      # @return [Boolean]
      def pair?
        @node.type.to_s == "pair"
      end

      # Check if this is a comment
      # @return [Boolean]
      def comment?
        @node.type.to_s == "comment"
      end

      # Get the key name if this is a pair node
      # @return [String, nil]
      def key_name
        return unless pair?

        # In JSONC tree-sitter, pair has key and value children
        key_node = find_child_by_field("key")

        return unless key_node

        # Key is typically a string, extract its content without quotes using byte positions
        key_text = node_text(key_node)
        # Remove surrounding quotes if present
        key_text&.gsub(/\A"|"\z/, "")
      end

      # Get the value node if this is a pair
      # @return [NodeWrapper, nil]
      def value_node
        return unless pair?

        value = find_child_by_field("value")

        return unless value

        NodeWrapper.new(value, lines: @lines, source: @source)
      end

      # Get key-value pairs if this is an object
      # @return [Array<NodeWrapper>]
      def pairs
        return [] unless object?

        result = []
        @node.each do |child|
          next if child.type.to_s == "comment"
          next unless child.type.to_s == "pair"

          result << NodeWrapper.new(child, lines: @lines, source: @source)
        end
        result
      end

      # Get array elements if this is an array
      # @return [Array<NodeWrapper>]
      def elements
        return [] unless array?

        result = []
        @node.each do |child|
          child_type = child.type.to_s
          # Skip punctuation and comments
          next if child_type == "comment"
          next if child_type == ","
          next if child_type == "["
          next if child_type == "]"

          result << NodeWrapper.new(child, lines: @lines, source: @source)
        end
        result
      end

      # Get mergeable children - the semantically meaningful children for tree merging
      # For objects, returns pairs. For arrays, returns elements.
      # For other node types, returns empty array (leaf nodes).
      # @return [Array<NodeWrapper>]
      def mergeable_children
        case type
        when :object
          pairs
        when :array
          elements
        else
          []
        end
      end

      # Check if this node is a container (has mergeable children)
      # @return [Boolean]
      def container?
        object? || array?
      end

      # Check if this is a root-level container (direct child of document)
      # Root-level containers get a generic signature so they always match.
      # @return [Boolean]
      def root_level_container?
        return false unless container?

        # Check if parent is a document node
        parent_node = @node.parent if @node.respond_to?(:parent)
        return false unless parent_node

        parent_node.type.to_s == "document"
      end

      # Get the opening line for a container node (the line with { or [)
      # For multi-line containers, returns the full line.
      # For single-line containers, returns just the opening bracket to avoid duplicating content.
      # @return [String, nil]
      def opening_line
        return unless container? && @start_line

        # If this is a single-line container, just return the opening bracket
        if @start_line == @end_line
          return opening_bracket
        end

        @lines[@start_line - 1]
      end

      # Get the closing line for a container node (the line with } or ])
      # For multi-line containers, returns the full line.
      # For single-line containers, returns just the closing bracket to avoid duplicating content.
      # @return [String, nil]
      def closing_line
        return unless container? && @end_line

        # If this is a single-line container, just return the closing bracket
        if @start_line == @end_line
          return closing_bracket
        end

        @lines[@end_line - 1]
      end

      # Get the opening bracket character for this container
      # @return [String, nil]
      def opening_bracket
        return "{" if object?
        return "[" if array?

        nil
      end

      # Get the closing bracket character for this container
      # @return [String, nil]
      def closing_bracket
        return "}" if object?
        return "]" if array?

        nil
      end

      # Find a child by field name
      # @param field_name [String] Field name to look for
      # @return [TreeSitter::Node, nil]
      def find_child_by_field(field_name)
        return unless @node.respond_to?(:child_by_field_name)

        @node.child_by_field_name(field_name)
      end

      # Find a child by type
      # @param type_name [String] Type name to look for
      # @return [TreeSitter::Node, nil]
      def find_child_by_type(type_name)
        return unless @node.respond_to?(:each)

        @node.each do |child|
          return child if child.type.to_s == type_name
        end
        nil
      end

      protected

      # Override wrap_child to use Jsonc::Merge::NodeWrapper
      def wrap_child(child)
        NodeWrapper.new(child, lines: @lines, source: @source)
      end

      def compute_signature(node)
        node_type = node.type.to_s

        case node_type
        when "document"
          # Root document - signature based on root content type
          child = nil
          node.each { |c|
            child = c unless c.type.to_s == "comment"
            break if child
          }
          child_type = child&.type&.to_s
          [:document, child_type]
        when "object"
          # For root-level objects (direct child of document), use a generic signature
          # that always matches so merging happens at the pair level.
          if root_level_container?
            [:root_object]
          else
            # Nested objects identified by their keys
            keys = extract_object_keys(node)
            [:object, keys.sort]
          end
        when "array"
          # For root-level arrays (direct child of document), use a generic signature
          if root_level_container?
            [:root_array]
          else
            # Nested arrays identified by their length and first few elements
            elements_count = 0
            node.each { |c| elements_count += 1 unless %w[comment , \[ \]].include?(c.type.to_s) }
            [:array, elements_count]
          end
        when "pair"
          # Pairs identified by their key name
          key = key_name
          [:pair, key]
        when "string"
          # Strings identified by their content
          [:string, node_text(node)]
        when "number"
          # Numbers identified by their value
          [:number, node_text(node)]
        when "true", "false"
          # Booleans
          [:boolean, node.type.to_s]
        when "null"
          [:null]
        when "comment"
          # Comments identified by their content
          [:comment, node_text(node)&.strip]
        else
          # Generic fallback
          content_preview = node_text(node)&.slice(0, 50)&.strip
          [node_type.to_sym, content_preview]
        end
      end

      private

      def extract_object_keys(object_node)
        keys = []
        object_node.each do |child|
          next unless child.type.to_s == "pair"

          key_node = child.respond_to?(:child_by_field_name) ? child.child_by_field_name("key") : nil

          # Fallback for backends without field access (FFI)
          unless key_node
            child.each do |pair_child|
              pair_child_type = pair_child.type.to_s
              next if pair_child_type == ":" || pair_child_type == "comment"
              key_node = pair_child
              break
            end
          end

          next unless key_node

          key_text = node_text(key_node)&.gsub(/\A"|"\z/, "")
          keys << key_text if key_text
        end
        keys
      end
    end
  end
end
