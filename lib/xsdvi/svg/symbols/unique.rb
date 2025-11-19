# frozen_string_literal: true

require_relative "../symbol"

module Xsdvi
  module SVG
    module Symbols
      # Symbol for XSD unique identity constraint
      class Unique < Symbol
        attr_accessor :name, :namespace

        def initialize
          super
          @name = nil
          @namespace = nil
        end

        def draw
          process_description
          draw_g_start
          print("<rect class='shadow' x='3' y='3' width='#{width}' " \
                "height='#{height}' rx='9'/>")
          print("<rect class='boxunique' x='0' y='0' width='#{width}' " \
                "height='#{height}' rx='9'/>")
          print("<text class='visible' x='5' y='13'>#{namespace}</text>") if namespace
          print("<text class='strong' x='5' y='27'>unique: #{name}</text>") if name
          draw_description(27)
          draw_connection
          draw_use
          draw_g_end
        end

        def calculate_width
          calc = Utils::WidthCalculator.new(MIN_WIDTH)
          calc.new_width(15, name, 8)
          calc.new_width(15, namespace)
          calc.width
        end

        def calculate_height
          MID_HEIGHT
        end
      end
    end
  end
end
