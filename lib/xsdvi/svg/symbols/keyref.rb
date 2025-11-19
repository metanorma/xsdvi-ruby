# frozen_string_literal: true

require_relative "../symbol"

module Xsdvi
  module SVG
    module Symbols
      # Symbol for XSD keyref identity constraint
      class Keyref < Symbol
        attr_accessor :name, :namespace, :refer

        def initialize
          super
          @name = nil
          @namespace = nil
          @refer = nil
        end

        def draw
          process_description
          draw_g_start
          print("<rect class='shadow' x='3' y='3' width='#{width}' " \
                "height='#{height}' rx='9'/>")
          print("<rect class='boxkeyref' x='0' y='0' width='#{width}' " \
                "height='#{height}' rx='9'/>")
          print("<text class='visible' x='5' y='13'>#{namespace}</text>") if namespace
          print("<text class='strong' x='5' y='27'>keyref: #{name}</text>") if name
          print("<text class='visible' x='5' y='41'>refer: #{refer}</text>") if refer
          draw_description(41)
          draw_connection
          draw_use
          draw_g_end
        end

        def calculate_width
          calc = Utils::WidthCalculator.new(MIN_WIDTH)
          calc.new_width(15, name, 8)
          calc.new_width(15, namespace)
          calc.new_width(15, refer, 7)
          calc.width
        end

        def calculate_height
          MAX_HEIGHT
        end
      end
    end
  end
end
