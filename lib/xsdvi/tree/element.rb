# frozen_string_literal: true

module Xsdvi
  module Tree
    # Represents a node in the tree structure
    class Element
      attr_accessor :parent
      attr_reader :children

      def initialize
        @parent = nil
        @children = []
      end

      def index
        return 1 unless parent?

        parent.children.index(self) + 1
      end

      def parent?
        !parent.nil?
      end

      def last_child
        children.last
      end

      def last_child?
        return true unless parent?

        parent.children.last == self
      end

      def first_child?
        return true unless parent?

        parent.children.first == self
      end

      def add_child(child)
        children << child
      end

      def children?
        !children.empty?
      end

      def code
        buffer = []
        element = self
        while element.parent?
          buffer.unshift(element.index)
          buffer.unshift("_")
          element = element.parent
        end
        buffer.unshift("_1")
        buffer.join
      end
    end
  end
end
