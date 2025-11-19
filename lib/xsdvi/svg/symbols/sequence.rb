# frozen_string_literal: true

require_relative "../symbol"

module Xsdvi
  module SVG
    module Symbols
      # Symbol for XSD sequence compositor
      class Sequence < Symbol
        attr_accessor :cardinality

        def initialize
          super
          @cardinality = nil
        end

        def draw
          process_description
          draw_g_start
          print("<rect class='boxcompositor' x='0' y='8' width='#{width}' " \
                "height='#{height}' rx='9'/>")
          print("<circle cx='#{(width / 2) + 12}' cy='14' r='2'/>")
          print("<circle cx='#{(width / 2) + 12}' cy='23' r='2'/>")
          print("<circle cx='#{(width / 2) + 12}' cy='32' r='2'/>")
          print("<text class='small' x='#{width / 2}' y='17'>1</text>")
          print("<text class='small' x='#{width / 2}' y='26'>2</text>")
          print("<text class='small' x='#{width / 2}' y='35'>3</text>")
          print("<line x1='#{(width / 2) + 12}' y1='14' x2='#{(width / 2) + 12}' y2='32'/>")
          print("<text x='5' y='52'>#{cardinality}</text>") if cardinality
          draw_description(52)
          draw_connection
          draw_use
          draw_g_end
        end

        def calculate_width
          calc = Utils::WidthCalculator.new(MIN_WIDTH)
          calc.new_width(15, cardinality)
          calc.width
        end

        def calculate_height
          MID_HEIGHT
        end
      end
    end
  end
end
