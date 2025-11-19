# frozen_string_literal: true

module Xsdvi
  module Utils
    # Calculates width for SVG elements based on text content
    class WidthCalculator
      attr_reader :width

      def initialize(min_width)
        @width = min_width
      end

      def new_width(char_width, text, additional = 0)
        return unless text

        text_length = text.is_a?(String) ? text.length : text
        calculated_width = char_width + (text_length * 6) + additional

        @width = calculated_width if calculated_width > @width
      end
    end
  end
end
