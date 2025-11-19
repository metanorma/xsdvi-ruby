# frozen_string_literal: true

require_relative "../symbol"

module Xsdvi
  module SVG
    module Symbols
      # Symbol for recursive loop references
      class Loop < Symbol
        def draw
          draw_g_start
          print("<rect class='boxloop' x='0' y='12' width='#{width}' " \
                "height='#{height}' rx='9'/>")
          print("<polygon class='filled' points='#{(width / 2) + 3},8 " \
                "#{(width / 2) - 2},12 #{(width / 2) + 3},17'/>")
          print("<polygon class='filled' points='#{width - 5},24 " \
                "#{width},19 #{width + 5},24'/>")
          print("<text x='10' y='27'>LOOP</text>")
          draw_connection
          draw_g_end
        end

        def calculate_width
          calc = Utils::WidthCalculator.new(MIN_WIDTH)
          calc.new_width(25, 4)
          calc.width
        end

        def calculate_height
          MIN_HEIGHT
        end
      end
    end
  end
end
