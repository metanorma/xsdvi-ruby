# frozen_string_literal: true

require_relative "../tree/element"

module Xsdvi
  module SVG
    # Base class for all SVG symbols
    class Symbol < Tree::Element
      # Process contents constants
      PC_STRICT = 1
      PC_SKIP = 2
      PC_LAX = 3

      # Layout constants
      X_INDENT = 45
      Y_INDENT = 25
      MIN_WIDTH = 60
      MAX_HEIGHT = 46
      MID_HEIGHT = 31
      MIN_HEIGHT = 21

      attr_accessor :x_position, :y_position, :width, :height,
                    :start_y_position, :svg, :description
      attr_reader :description_string_array, :y_shift,
                  :additional_height

      def initialize
        super
        @x_position = 0
        @y_position = 0
        @width = 0
        @height = 0
        @start_y_position = 50
        @description = []
        @description_string_array = []
        @y_shift = 14
        @additional_height = 0
      end

      def x_end
        x_position + width
      end

      def y_end
        y_position + MAX_HEIGHT
      end

      def prepare_box
        if parent?
          @x_position = parent.x_end + X_INDENT
          highest = Symbol.highest_y_position || 0
          @y_position = if first_child?
                          highest
                        else
                          highest + MAX_HEIGHT + Y_INDENT
                        end
        else
          @x_position = 20
          @y_position = start_y_position
        end

        # Ensure values are integers
        @x_position = @x_position.to_i
        @y_position = @y_position.to_i
        @width = calculate_width
        @height = calculate_height
        Symbol.highest_y_position = @y_position
      end

      def draw
        raise NotImplementedError, "Subclasses must implement draw method"
      end

      def calculate_width
        MIN_WIDTH
      end

      def calculate_height
        MAX_HEIGHT
      end

      class << self
        attr_accessor :highest_y_position, :additional_height_rest,
                      :prev_x_position, :prev_y_position

        def reset_class_variables
          @highest_y_position = 0
          @additional_height_rest = 0
          @prev_x_position = 0
          @prev_y_position = 0
        end
      end

      reset_class_variables

      protected

      def print(string)
        svg.print(string)
      end

      def draw_g_start
        rest = Symbol.additional_height_rest || 0
        prev_x = Symbol.prev_x_position || 0
        # Always include y_position as integer
        print("<g id='#{code}' class='box' " \
              "transform='translate(#{x_position.to_i},#{y_position.to_i})' " \
              "data-desc-height='#{additional_height.to_i}' " \
              "data-desc-height-rest='#{rest.to_i}' " \
              "data-desc-x='#{prev_x.to_i}'>")
      end

      def draw_g_end
        print("</g>\n")
      end

      def draw_connection
        if last_child? && !first_child?
          y_offset = parent.y_position - y_position + (MAX_HEIGHT / 2)
          print("<line class='connection' id='p#{code}' " \
                "x1='#{10 - X_INDENT}' y1='#{y_offset}' " \
                "x2='#{10 - X_INDENT}' y2='#{-15 - Y_INDENT}'/>")
          print("<path class='connection' " \
                "d='M#{10 - X_INDENT},#{-15 - Y_INDENT} " \
                "Q#{10 - X_INDENT},15 0,#{MAX_HEIGHT / 2}'/>")
        elsif parent?
          print("<line class='connection' " \
                "x1='#{10 - X_INDENT}' y1='#{MAX_HEIGHT / 2}' " \
                "x2='0' y2='#{MAX_HEIGHT / 2}'/>")
        end
      end

      def draw_use
        return unless children?

        code_str = code
        print("<use x='#{width - 1}' y='#{(MAX_HEIGHT / 2) - 6}' " \
              "xlink:href='#minus' id='s#{code_str}' " \
              "onclick='show(\"#{code_str}\")'/>")
      end

      def draw_mouseover
        print("onmouseover='makeVisible(\"#{code}\")' " \
              "onmouseout='makeHidden(\"#{code}\")'/>")
      end

      def process_description
        return if description.empty?

        wrap_length = (width / 5.5).round
        strings_with_breaks = []

        description.each do |desc_string|
          # WordUtils.wrap returns string with \n embedded, then split
          wrapped_string = word_utils_wrap(desc_string, wrap_length)
          wrapped_lines = wrapped_string.split("\n")
          strings_with_breaks.concat(wrapped_lines)
          # Match Java bug: accumulate TOTAL size, not just new lines
          @additional_height += y_shift * strings_with_breaks.size
        end

        @description_string_array = strings_with_breaks

        prev_y = Symbol.prev_y_position || 0
        curr_y = y_position || 0

        if curr_y > prev_y && prev_y != 0
          rest = Symbol.additional_height_rest || 0
          rest -= height
          rest = 0 if rest.negative?
          rest = additional_height if rest < additional_height
          Symbol.additional_height_rest = rest
        elsif additional_height != 0
          Symbol.additional_height_rest = additional_height
        end

        Symbol.prev_x_position = x_position unless description.empty?
        Symbol.prev_y_position = y_position
      end

      def draw_description(y_start)
        description_string_array.each do |line|
          y_start += y_shift
          escaped_line = line.gsub("<", "&lt;").gsub(">", "&gt;")
          print("<text x='5' y='#{y_start}' class='desc'>#{escaped_line}</text>")
        end
      end

      # Apache Commons WordUtils.wrap(str, wrapLength, newLineStr, wrapLongWords)
      # Wraps text at wrapLength, inserting newLineStr, optionally breaking long words
      # Java WordUtils processes multi-line input by handling each line separately
      def word_utils_wrap(input, wrap_length)
        return input if input.nil? || wrap_length < 1

        # Split by existing newlines first (like Java WordUtils does)
        input_lines = input.split("\n", -1)  # -1 to preserve trailing empty strings
        result_lines = []

        input_lines.each do |line|
          # Handle empty lines
          if line.empty?
            result_lines << ""
            next
          end

          # Skip wrapping if line is strictly shorter than wrap_length
          # Apache Commons only skips if length < wrap_length, not <=
          if line.length < wrap_length
            result_lines << line
            next
          end

          # Wrap this line
          offset = 0
          line_length = line.length

          while offset < line_length
            # Rest of line fits?
            if line_length - offset <= wrap_length
              result_lines << line[offset..]
              break
            end

            # Find last space before wrap point
            space_idx = line.rindex(" ", offset + wrap_length)

            if space_idx && space_idx >= offset
              # Found space to break at
              result_lines << line[offset...space_idx]
              offset = space_idx + 1
            else
              # No space found - break at wrap_length (wrapLongWords=true)
              result_lines << line[offset...(offset + wrap_length)]
              offset += wrap_length
            end
          end
        end

        result_lines.join("\n")
      end
    end
  end
end
