# frozen_string_literal: true

require_relative "../symbol"

module Xsdvi
  module SVG
    module Symbols
      # Symbol for XSD any wildcard
      class Any < Symbol
        attr_accessor :namespace, :process_contents, :cardinality

        def initialize
          super
          @namespace = nil
          @process_contents = PC_STRICT
          @cardinality = nil
        end

        def draw
          process_description
          draw_g_start
          print("<rect class='shadow' x='3' y='3' width='#{width}' height='#{height}'/>")
          print("<rect class='boxany' x='0' y='0' width='#{width}' height='#{height}'/>")

          # Draw process contents boxes
          pc_class = case process_contents
                     when PC_STRICT then "strict"
                     when PC_SKIP then "skip"
                     when PC_LAX then "lax"
                     else "strict"
                     end
          print("<rect class='#{pc_class}' x='6' y='34' width='6' height='6'/>")
          print("<rect class='#{pc_class}' x='16' y='34' width='6' height='6'/>")
          print("<rect class='#{pc_class}' x='26' y='34' width='6' height='6'/>")

          print("<text x='5' y='13'>#{namespace}</text>") if namespace
          # Java shows just angle brackets <> not <any>
          print("<text class='strong' x='5' y='27'>&lt;&gt;</text>")
          print("<text x='5' y='59'>#{cardinality}</text>") if cardinality
          draw_description(59)
          draw_connection
          draw_use
          draw_g_end
        end

        def calculate_width
          calc = Utils::WidthCalculator.new(MIN_WIDTH)
          calc.new_width(15, namespace)
          calc.new_width(15, cardinality)
          calc.width
        end

        def calculate_height
          MAX_HEIGHT
        end
      end
    end
  end
end
