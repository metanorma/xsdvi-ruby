# frozen_string_literal: true

require "nokogiri"

module Xsdvi
  module Comparison
    # Extracts metadata from SVG files for comparison
    class MetadataExtractor
      # Extract metadata from all SVG files in a directory
      # @param svg_dir [String] Directory containing SVG files
      # @return [Hash] Metadata including file count, sizes, and symbol counts
      def extract(svg_dir)
        files = Dir.glob(File.join(svg_dir, "*.svg"))

        {
          file_count: files.length,
          total_size: files.sum { |f| File.size(f) },
          total_size_kb: (files.sum { |f| File.size(f) } / 1024.0).round(1),
          files: files.map { |f| analyze_file(f) },
        }
      end

      private

      # Analyze a single SVG file
      # @param svg_file [String] Path to SVG file
      # @return [Hash] File metadata and symbol counts
      def analyze_file(svg_file)
        content = File.read(svg_file)
        doc = Nokogiri::XML(content)
        # Remove namespaces to simplify XPath queries
        doc.remove_namespaces!

        {
          name: File.basename(svg_file),
          size: File.size(svg_file),
          size_kb: (File.size(svg_file) / 1024.0).round(1),
          elements: count_by_class(doc, "boxelement"),
          optional_elements: count_by_class(doc, "boxelementoptional"),
          attributes: count_by_class(doc, "boxattribute1", "boxattribute2"),
          sequences: count_by_class(doc, "boxsequence"),
          choices: count_by_class(doc, "boxchoice"),
          all_compositors: count_by_class(doc, "boxall"),
          compositors: count_by_class(doc, "boxcompositor"),
          any: count_by_class(doc, "boxany"),
          any_attribute: count_by_class(doc, "boxanyAttribute"),
          keys: count_by_class(doc, "boxkey"),
          keyrefs: count_by_class(doc, "boxkeyref"),
          uniques: count_by_class(doc, "boxunique"),
          selectors: count_by_class(doc, "boxselector"),
          fields: count_by_class(doc, "boxfield"),
          loops: count_by_class(doc, "boxloop"),
          schemas: count_by_class(doc, "boxschema"),
          total_symbols: count_all_boxes(doc),
        }
      end

      # Count rectangles with specific CSS classes
      # @param doc [Nokogiri::XML::Document] Parsed SVG document
      # @param classes [Array<String>] CSS class names to match
      # @return [Integer] Count of matching rectangles
      def count_by_class(doc, *classes)
        xpath = classes.map { |c| "@class='#{c}'" }.join(" or ")
        doc.xpath("//rect[#{xpath}]").count
      end

      # Count all box elements (symbols)
      # @param doc [Nokogiri::XML::Document] Parsed SVG document
      # @return [Integer] Total count of box elements
      def count_all_boxes(doc)
        doc.xpath("//rect[starts-with(@class, 'box')]").count
      end
    end
  end
end
