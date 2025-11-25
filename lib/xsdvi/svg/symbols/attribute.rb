# frozen_string_literal: true

require_relative "../symbol"

module Xsdvi
  module SVG
    module Symbols
      # Symbol for XSD attributes
      class Attribute < Symbol
        attr_accessor :name, :namespace, :type, :required, :constraint

        def initialize
          super
          @name = nil
          @namespace = nil
          @type = nil
          @required = false
          @constraint = nil
        end

        def draw
          process_description
          draw_g_start
          print("<rect class='shadow' x='3' y='3' width='#{width}' " \
                "height='#{height}' rx='9'/>")
          if required
            print("<rect class='boxattribute1' x='0' y='0' " \
                  "width='#{width}' height='#{height}' rx='9'")
          else
            print("<rect class='boxattribute2' x='0' y='0' " \
                  "width='#{width}' height='#{height}' rx='9'")
          end
          print("/>")

          print("<text class='visible' x='5' y='13'>#{namespace}</text>") if namespace
          print("<text class='strong' x='5' y='27'><tspan class='big'>@</tspan> #{name}</text>") if name
          print("<text class='visible' x='5' y='41'>#{type}</text>") if type

          properties = []
          properties << constraint if constraint
          print("<text x='5' y='59'>#{properties.join(', ')}</text>")

          draw_description(59)
          draw_connection
          draw_g_end
        end

        def calculate_width
          calc = Utils::WidthCalculator.new(MIN_WIDTH)
          calc.new_width(15, name, 3)
          calc.new_width(15, namespace)
          calc.new_width(15, type)
          calc.new_width(15, 13)
          calc.new_width(15, constraint)  # Constraint includes "default: " or "fixed: " prefix
          calc.width
        end

        def calculate_height
          MAX_HEIGHT
        end
      end
    end
  end
end
