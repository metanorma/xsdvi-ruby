# frozen_string_literal: true

module Xsdvi
  module Tree
    # Builds a tree structure
    class Builder
      attr_accessor :root
      attr_reader :parent

      def initialize
        @parent = nil
        @root = nil
      end

      def append_child(child)
        parent.add_child(child)
        child.parent = parent
        @parent = child
      end

      def level_up
        @parent = parent.parent
      end

      def set_root(new_root)
        @parent = new_root
        @root = new_root
      end
    end
  end
end
