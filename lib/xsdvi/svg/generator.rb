# frozen_string_literal: true

require_relative "../utils/resource_loader"

module Xsdvi
  module SVG
    # Generates SVG files from symbol trees
    class Generator
      attr_accessor :writer, :embody_style, :style_uri, :hide_menu_buttons

      def initialize(writer)
        @writer = writer
        @embody_style = true
        @style_uri = nil
        @hide_menu_buttons = false
        @resource_loader = Utils::ResourceLoader.new
      end

      def draw(root_symbol)
        # Reset class variables before drawing
        Symbol.reset_class_variables

        svg_begin
        draw_symbol(root_symbol)
        svg_end
      end

      def print_extern_style
        writer.new_writer(style_uri)
        print(load_resource("svg/style.css"))
        writer.close
      end

      def print(string)
        writer.append("#{string}\n")
      end

      private

      def svg_begin
        print(load_resource("svg/xml_declaration.xml"))
        print_style_ref unless embody_style
        print(load_resource("svg/doctype.txt"))
        print(load_resource("svg/svg_start.txt"))
        print(load_resource("svg/title.txt"))

        script = load_resource("svg/script.js")
        script = script.gsub("%HEIGHT_SUM%", (Symbol::MAX_HEIGHT + Symbol::Y_INDENT).to_s)
        script = script.gsub("%HEIGHT_HALF%", (Symbol::MAX_HEIGHT / 2).to_s)
        print(script)

        print_defs(embody_style, true)
        print("")
        print(load_resource("svg/menu_buttons.svg")) unless hide_menu_buttons
      end

      def svg_end
        print(load_resource("svg/svg_end.txt"))
        writer.close
      end

      def print_style_ref
        style_template = load_resource("svg/style.xml")
        print(style_template.gsub("%STYLE_URI%", style_uri))
      end

      def print_embodied_style
        style_template = load_resource("svg/style.html")
        style = load_resource("svg/style.css")
        print(style_template.gsub("%STYLE%", style))
      end

      def print_defs(style, symbols)
        print("<defs>")
        print_embodied_style if style
        print(load_resource("svg/defined_symbols.svg")) if symbols
        print("</defs>")
      end

      def draw_symbol(symbol)
        symbol.svg = self
        symbol.prepare_box
        symbol.draw
        symbol.children.each do |child|
          draw_symbol(child)
        end
      end

      def load_resource(path)
        @resource_loader.read_resource_file(path)
      end
    end
  end
end
