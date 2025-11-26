# frozen_string_literal: true

require "fileutils"
require "nokogiri"

module Xsdvi
  module Comparison
    # Orchestrates dual generation with Java and Ruby XsdVi
    class DualGenerator
      attr_reader :xsd_file, :output_dir

      def initialize(xsd_file, options = {})
        @xsd_file = xsd_file
        @root = options[:root_node_name]
        @output_dir = options[:output_path] || default_output_dir
        @skip_java = options[:skip_java]
        @skip_ruby = options[:skip_ruby]
      end

      # Generate comparison
      # @return [Hash] Generation results with paths and metadata
      def generate
        validate_inputs
        setup_directories

        # Generate Java output
        java_start = Time.now
        generate_java unless @skip_java
        java_time = Time.now - java_start

        # Generate Ruby output
        ruby_start = Time.now
        generate_ruby unless @skip_ruby
        ruby_time = Time.now - ruby_start

        # Extract metadata
        java_metadata = extract_metadata(java_dir)
        ruby_metadata = extract_metadata(ruby_dir)

        # Add timing info
        java_metadata[:generation_time] = java_time.round(2) unless @skip_java
        ruby_metadata[:generation_time] = ruby_time.round(2) unless @skip_ruby

        # Generate HTML comparison
        html_file = generate_html(java_metadata, ruby_metadata)

        {
          output_dir: @output_dir,
          html_file: html_file,
          java: java_metadata,
          ruby: ruby_metadata,
        }
      end

      private

      # Validate inputs
      def validate_inputs
        raise "XSD file not found: #{@xsd_file}" unless File.exist?(@xsd_file)
        raise "Must generate at least one implementation" if @skip_java && @skip_ruby
      end

      # Setup output directories
      def setup_directories
        FileUtils.mkdir_p(java_dir)
        FileUtils.mkdir_p(ruby_dir)
      end

      # Get Java output directory
      # @return [String] Java directory path
      def java_dir
        File.join(@output_dir, "java")
      end

      # Get Ruby output directory
      # @return [String] Ruby directory path
      def ruby_dir
        File.join(@output_dir, "ruby")
      end

      # Generate Java XsdVi output
      def generate_java
        puts "Generating Java XsdVi output..."
        manager = JavaManager.new

        options = {}
        options[:root] = @root if @root

        manager.generate(@xsd_file, java_dir, options)
      end

      # Generate Ruby XsdVi output
      def generate_ruby
        puts "Generating Ruby XsdVi output..."

        # Set up the generation pipeline (same as CLI)
        builder = Tree::Builder.new
        xsd_handler = XsdHandler.new(builder)
        writer_helper = Utils::Writer.new
        svg_generator = SVG::Generator.new(writer_helper)

        # Configure handler
        xsd_handler.root_node_name = @root
        # one_node_only should only be true when generating all elements separately
        xsd_handler.one_node_only = (@root == "all")

        # Configure generator
        svg_generator.hide_menu_buttons = (@root == "all")
        svg_generator.embody_style = true

        # Parse XSD
        xsd_handler.process_file(@xsd_file)

        # Generate output file(s)
        if @root == "all"
          generate_ruby_all_elements(xsd_handler, svg_generator, builder,
                                     writer_helper)
        else
          generate_ruby_single(svg_generator, builder, writer_helper)
        end
      end

      # Generate Ruby output for all elements
      def generate_ruby_all_elements(xsd_handler, svg_generator, builder,
writer_helper)
        doc = Nokogiri::XML(File.read(@xsd_file))
        element_names = xsd_handler.get_elements_names(doc)

        element_names.each do |elem_name|
          # Reset for each element
          builder = Tree::Builder.new
          handler = XsdHandler.new(builder)
          handler.root_node_name = elem_name
          handler.one_node_only = true
          handler.set_schema_namespace(doc, elem_name)
          handler.process_file(@xsd_file)

          output_file = File.join(ruby_dir, "#{elem_name}.svg")
          writer_helper.new_writer(output_file)
          svg_generator.draw(builder.root) if builder.root
        end
      end

      # Generate Ruby output for single element
      def generate_ruby_single(svg_generator, builder, writer_helper)
        filename = if @root
                     "#{@root}.svg"
                   else
                     "#{File.basename(@xsd_file, '.xsd')}.svg"
                   end

        output_file = File.join(ruby_dir, filename)
        writer_helper.new_writer(output_file)
        svg_generator.draw(builder.root) if builder.root
      end

      # Extract metadata from output directory
      # @param dir [String] Directory path
      # @return [Hash] Extracted metadata
      def extract_metadata(dir)
        extractor = MetadataExtractor.new
        extractor.extract(dir)
      end

      # Generate HTML comparison page
      # @param java_meta [Hash] Java metadata
      # @param ruby_meta [Hash] Ruby metadata
      # @return [String] Path to HTML file
      def generate_html(java_meta, ruby_meta)
        puts "Generating comparison HTML..."

        generator = HtmlGenerator.new
        generator.generate(
          @output_dir,
          java_meta,
          ruby_meta,
          schema_name: File.basename(@xsd_file, ".xsd"),
        )
      end

      # Generate default output directory path
      # @return [String] Default directory path
      def default_output_dir
        timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
        schema_name = File.basename(@xsd_file, ".xsd")
        File.join("comparisons", "#{schema_name}-#{timestamp}")
      end
    end
  end
end
