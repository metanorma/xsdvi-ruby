# frozen_string_literal: true

require_relative "../symbol"

module Xsdvi
  module SVG
    module Symbols
      # Symbol for XSD elements
      class Element < Symbol
        attr_accessor :name, :namespace, :type, :cardinality, :nillable,
                      :abstract, :substitution, :optional

        def initialize
          super
          @name = nil
          @namespace = nil
          @type = nil
          @cardinality = nil
          @optional = false
          @nillable = false
          @abstract = false
          @substitution = nil
        end

        def cardinality=(value)
          @cardinality = value
          @optional = true if value&.start_with?("0")
        end

        def draw
          print("<a href=\"#\" onclick=\"window.parent.location.href = " \
                "window.parent.location.href.split('#')[0]  + " \
                "'#element_#{name}'\">")

          process_description

          draw_g_start
          print("<rect class='shadow' x='3' y='3' width='#{width}' " \
                "height='#{height}'/>")
          if optional
            print("<rect class='boxelementoptional' x='0' y='0' " \
                  "width='#{width}' height='#{height}'/>")
          else
            print("<rect class='boxelement' x='0' y='0' width='#{width}' " \
                  "height='#{height}'/>")
          end

          # Show namespace at y=13 (always shown in Java if present)
          if namespace && !namespace.empty?
            print("<text class='visible' x='5' y='13'>#{namespace}</text>")
          end

          # Show name at y=27 (always shown in Java)
          print("<text class='strong elementlink' x='5' y='27'>#{name}</text>") if name

          # Show type at y=41 (always shown in Java if present)
          print("<text class='visible' x='5' y='41'>#{type}</text>") if type && !type.empty?

          # Properties at y=59
          properties = []
          properties << cardinality if cardinality
          properties << "subst.: #{substitution}" if substitution
          properties << "nillable: true" if nillable
          properties << "abstract: true" if abstract
          print("<text x='5' y='59'>#{properties.join(', ')}</text>")

          draw_description(59)
          draw_connection
          draw_use
          draw_g_end
          print("</a>")
        end

        def calculate_width
          calc = Utils::WidthCalculator.new(MIN_WIDTH)
          calc.new_width(15, name, 3)
          calc.new_width(15, namespace)
          calc.new_width(15, type)
          calc.new_width(15, cardinality)
          calc.new_width(15, substitution ? 22 : 11)
          calc.new_width(15, substitution, 8)
          calc.width
        end

        def calculate_height
          MAX_HEIGHT
        end
      end
    end
  end
end
