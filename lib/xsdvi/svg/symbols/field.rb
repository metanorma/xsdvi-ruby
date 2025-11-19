# frozen_string_literal: true

require_relative "../symbol"

module Xsdvi
  module SVG
    module Symbols
      # Symbol for XSD field
      class Field < Symbol
        attr_accessor :xpath

        def initialize
          super
          @xpath = nil
        end

        def draw
          draw_g_start
          print("<rect class='shadow' x='3' y='3' width='#{width}' " \
                "height='#{height}' rx='9'/>")
          print("<rect class='boxfield' x='0' y='0' width='#{width}' " \
                "height='#{height}' rx='9'/>")
          print("<text class='strong' x='5' y='13'>field</text>")
          print("<text class='visible' x='5' y='27'>#{xpath}</text>") if xpath
          draw_connection
          draw_g_end
        end

        def calculate_width
          calc = Utils::WidthCalculator.new(MIN_WIDTH)
          calc.new_width(15, 5)
          calc.new_width(15, xpath)
          calc.width
        end

        def calculate_height
          MID_HEIGHT
        end
      end
    end
  end
end
