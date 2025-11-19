# frozen_string_literal: true

require_relative "../symbol"

module Xsdvi
  module SVG
    module Symbols
      # Symbol for XSD schema root
      class Schema < Symbol
        def prepare_box
          # Schema root positioning
          @x_position = 20
          @y_position = 50
          @width = calculate_width
          @height = calculate_height

          # Set highest to 50 so children start at 50
          # Must use Symbol.highest_y_position, not self.class
          Symbol.highest_y_position = 50
        end

        def draw
          draw_g_start
          print("<rect class='boxschema' x='0' y='12' width='#{width}' height='#{height}'/>")
          print("<text x='5' y='27'><tspan class='big'>/ </tspan>schema</text>")
          draw_use
          draw_g_end
        end

        def calculate_width
          calc = Utils::WidthCalculator.new(MIN_WIDTH)
          calc.new_width(15, 8)
          calc.width
        end

        def calculate_height
          MIN_HEIGHT
        end
      end
    end
  end
end
