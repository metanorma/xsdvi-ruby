# frozen_string_literal: true

require_relative "../symbol"

module Xsdvi
  module SVG
    module Symbols
      # Symbol for XSD choice compositor
      class Choice < Symbol
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
          print("<circle class='empty' cx='#{(width / 2) + 12}' cy='23' r='2'/>")
          print("<circle class='empty' cx='#{(width / 2) + 12}' cy='32' r='2'/>")
          print("<polyline points='#{(width / 2) - 4},23 #{(width / 2) + 4},23 " \
                "#{(width / 2) + 4},14 #{(width / 2) + 10},14'/>")
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
