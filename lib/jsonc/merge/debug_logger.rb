# frozen_string_literal: true

module Jsonc
  module Merge
    # Debug logging utility for Jsonc::Merge.
    # Extends the base Ast::Merge::DebugLogger with Jsonc-specific configuration.
    #
    # @example Enable debug logging
    #   ENV['JSON_MERGE_DEBUG'] = '1'
    #   DebugLogger.debug("Processing node", {type: "pair", line: 5})
    #
    # @example Disable debug logging (default)
    #   DebugLogger.debug("This won't be printed", {})
    module DebugLogger
      extend Ast::Merge::DebugLogger

      # Jsonc-specific configuration
      self.env_var_name = "JSONC_MERGE_DEBUG"
      self.log_prefix = "[Jsonc::Merge]"

      # Override log_node to handle Json-specific node types.
      #
      # @param node [Object] Node to log information about
      # @param label [String] Label for the node
      def self.log_node(node, label: "Node")
        return unless enabled?

        info = case node
        when Jsonc::Merge::FreezeNode
          {type: "FreezeNode", lines: "#{node.start_line}..#{node.end_line}"}
        when Jsonc::Merge::NodeWrapper
          {type: node.type.to_s, lines: "#{node.start_line}..#{node.end_line}"}
        else
          extract_node_info(node)
        end

        debug(label, info)
      end
    end
  end
end
