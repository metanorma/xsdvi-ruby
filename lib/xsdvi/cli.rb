# frozen_string_literal: true

require "thor"
require "fileutils"

module Xsdvi
  # Command-line interface for XSDVI
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "generate INPUT [INPUT2...] [OPTIONS]",
         "Generate SVG diagrams from XSD schema files"
    method_option :root_node_name,
                  type: :string,
                  aliases: "-r",
                  desc: "Schema root node name (or 'all' for all elements)"
    method_option :one_node_only,
                  type: :boolean,
                  aliases: "-o",
                  desc: "Show only one element"
    method_option :output_path,
                  type: :string,
                  aliases: "-p",
                  desc: "Output folder path"
    method_option :embody_style,
                  type: :boolean,
                  default: true,
                  desc: "Embody CSS style in SVG (default: true)"
    method_option :generate_style,
                  type: :string,
                  desc: "Generate CSS file with specified name"
    method_option :use_style,
                  type: :string,
                  desc: "Use external CSS file at specified URL"
    def generate(*inputs)
      if inputs.empty?
        puts "Error: No input files specified"
        exit(1)
      end

      # Validate input files exist
      inputs.each do |input|
        unless File.exist?(input)
          puts "Error: XSD file '#{input}' not found!"
          exit(1)
        end
      end

      # Process options
      root_node_name = options[:root_node_name]
      one_node_only = options[:one_node_only]
      one_node_only = true if root_node_name == "all"
      output_path = options[:output_path]

      # Determine style mode
      style_mode = determine_style_mode(options)

      # Process each input file
      builder = Tree::Builder.new
      xsd_handler = XsdHandler.new(builder)
      writer_helper = Utils::Writer.new
      svg_generator = SVG::Generator.new(writer_helper)

      svg_generator.hide_menu_buttons = one_node_only

      apply_style_settings(svg_generator, style_mode, options)

      inputs.each do |input|
        # Special handling for -r all: generate file for each element
        if root_node_name == "all"
          process_all_elements(
            input,
            xsd_handler,
            svg_generator,
            builder,
            writer_helper,
            output_path,
          )
        else
          process_input_file(
            input,
            xsd_handler,
            svg_generator,
            builder,
            writer_helper,
            root_node_name,
            one_node_only,
            output_path,
          )
        end
      end
    end

    desc "compare INPUT", "Compare Java and Ruby XsdVi outputs side-by-side"
    method_option :root_node_name,
                  type: :string,
                  aliases: "-r",
                  desc: "Schema root node name (or 'all' for all elements)"
    method_option :output_path,
                  type: :string,
                  aliases: "-o",
                  desc: "Output directory (default: ./comparisons/<name>-<timestamp>)"
    method_option :skip_java,
                  type: :boolean,
                  default: false,
                  desc: "Skip Java generation (use existing output)"
    method_option :skip_ruby,
                  type: :boolean,
                  default: false,
                  desc: "Skip Ruby generation (use existing output)"
    method_option :open,
                  type: :boolean,
                  default: false,
                  aliases: "-O",
                  desc: "Open comparison HTML in browser automatically"
    def compare(input)
      unless File.exist?(input)
        puts "Error: XSD file '#{input}' not found!"
        exit(1)
      end

      puts "=" * 60
      puts "XsdVi Comparison Tool"
      puts "=" * 60
      puts "Schema: #{input}"
      puts ""

      begin
        generator = Comparison::DualGenerator.new(input, options)
        result = generator.generate

        puts ""
        puts "=" * 60
        puts "Comparison Complete!"
        puts "=" * 60
        puts ""
        puts "Output directory: #{result[:output_dir]}"
        puts "HTML comparison:  #{result[:html_file]}"
        puts ""

        if result[:java][:file_count] && result[:java][:generation_time] && result[:java][:generation_time]
          puts "Java:  #{result[:java][:total_size_kb]} KB, " \
               "#{result[:java][:file_count]} file(s), " \
               "#{result[:java][:generation_time]}s"
        end

        if result[:ruby][:file_count] && result[:ruby][:generation_time] && result[:ruby][:generation_time]
          puts "Ruby:  #{result[:ruby][:total_size_kb]} KB, " \
               "#{result[:ruby][:file_count]} file(s), " \
               "#{result[:ruby][:generation_time]}s"
        end

        puts ""

        if options[:open]
          open_in_browser(result[:html_file])
        else
          puts "Open #{result[:html_file]} in your browser to view the comparison"
        end
      rescue StandardError => e
        puts ""
        puts "Error: #{e.message}"
        puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
        exit(1)
      end
    end

    default_task :generate

    private

    def process_all_elements(input, xsd_handler, svg_generator, builder,
                             writer_helper, output_path)
      # First, parse the schema to get all element names
      doc = Nokogiri::XML(File.read(input))
      element_names = xsd_handler.get_elements_names(doc)

      if element_names.empty?
        warn "No root elements found in schema!"
        return
      end

      puts "Generating #{element_names.size} diagrams for all elements..."

      # Generate a separate diagram for each element
      element_names.each do |elem_name|
        # Reset builder for each element
        builder = Tree::Builder.new
        xsd_handler = XsdHandler.new(builder)
        xsd_handler.root_node_name = elem_name
        xsd_handler.one_node_only = true
        xsd_handler.set_schema_namespace(doc, elem_name)

        # Process the schema with this specific root element
        xsd_handler.process_file(input)

        # Generate output filename
        output_file = generate_output_filename(
          input,
          elem_name,
          true, # one_node_only
          output_path,
        )

        writer_helper.new_writer(output_file)

        if builder.root
          svg_generator.draw(builder.root)
          puts "  Generated #{output_file}"
        else
          warn "  Skipped #{elem_name} (empty)"
        end
      end

      puts "Done."
    end

    def determine_style_mode(options)
      return :generate_style if options[:generate_style]
      return :use_style if options[:use_style]

      :embody_style
    end

    def apply_style_settings(svg_generator, style_mode, options)
      case style_mode
      when :embody_style
        puts "The style will be embodied"
        svg_generator.embody_style = true
      when :generate_style
        style_url = options[:generate_style]
        puts "Generating style #{style_url}..."
        svg_generator.embody_style = false
        svg_generator.style_uri = style_url
        svg_generator.print_extern_style
        puts "Done."
      when :use_style
        style_url = options[:use_style]
        puts "Using external style #{style_url}"
        svg_generator.embody_style = false
        svg_generator.style_uri = style_url
      end
    end

    def process_input_file(input, xsd_handler, svg_generator, builder,
                           writer_helper, root_node_name, one_node_only,
                           output_path)
      puts "Parsing #{input}..."

      xsd_handler.root_node_name = root_node_name
      xsd_handler.one_node_only = one_node_only

      # Parse and process XSD
      xsd_handler.process_file(input)

      puts "Processing XML Schema model..."

      # Generate output filename
      output_file = generate_output_filename(
        input,
        root_node_name,
        one_node_only,
        output_path,
      )

      puts "Drawing SVG #{output_file}..."
      writer_helper.new_writer(output_file)

      if builder.root
        svg_generator.draw(builder.root)
        puts "Done."
      else
        warn "SVG is empty!"
      end
    end

    def generate_output_filename(input, root_node_name, one_node_only,
                                  output_path)
      basename = File.basename(input, ".*")
      filename = if root_node_name && one_node_only
                   "#{root_node_name}.svg"
                 else
                   "#{basename}.svg"
                 end

      if output_path
        FileUtils.mkdir_p(output_path)
        File.join(output_path, filename)
      else
        filename
      end
    end

    def open_in_browser(file)
      puts "Opening comparison in browser..."

      # Get absolute path for browser
      abs_path = File.expand_path(file)

      case RbConfig::CONFIG["host_os"]
      when /darwin/
        system("open", abs_path)
      when /linux/
        system("xdg-open", abs_path)
      when /mswin|mingw|cygwin/
        system("start", abs_path)
      else
        puts "Unable to auto-open browser on this platform"
        puts "Please open #{file} manually"
      end
    end
  end
end
