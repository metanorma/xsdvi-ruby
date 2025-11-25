# frozen_string_literal: true

require "json"

module Xsdvi
  module Comparison
    # Generates HTML comparison page
    class HtmlGenerator
      TEMPLATE_PATH = File.join(__dir__, "../../../resources/comparison/template.html")

      # Generate HTML comparison page
      # @param output_dir [String] Output directory path
      # @param java_metadata [Hash] Java generation metadata
      # @param ruby_metadata [Hash] Ruby generation metadata
      # @param options [Hash] Generation options
      # @option options [String] :schema_name Schema name for display
      # @return [String] Path to generated HTML file
      def generate(output_dir, java_metadata, ruby_metadata, options = {})
        template = File.read(TEMPLATE_PATH)

        html = template
          .gsub("{{SCHEMA_NAME}}", options[:schema_name] || "Schema")
          .gsub("{{JAVA_METADATA}}", format_metadata_json(java_metadata))
          .gsub("{{RUBY_METADATA}}", format_metadata_json(ruby_metadata))
          .gsub("{{STATS_TABLE}}", generate_stats_table(java_metadata, ruby_metadata))
          .gsub("{{ELEMENT_SELECTOR}}", generate_element_selector(java_metadata, ruby_metadata))
          .gsub("{{IS_MULTI_FILE}}", (java_metadata[:file_count] > 1).to_s)

        output_file = File.join(output_dir, "comparison.html")
        File.write(output_file, html)

        output_file
      end

      private

      # Format metadata as JSON
      # @param metadata [Hash] Metadata hash
      # @return [String] Pretty-printed JSON
      def format_metadata_json(metadata)
        JSON.pretty_generate(metadata)
      end

      # Generate statistics comparison table HTML
      # @param java_meta [Hash] Java metadata
      # @param ruby_meta [Hash] Ruby metadata
      # @return [String] HTML table
      def generate_stats_table(java_meta, ruby_meta)
        rows = []

        # File counts
        rows << table_row(
          "Files",
          java_meta[:file_count],
          ruby_meta[:file_count],
          java_meta[:file_count] == ruby_meta[:file_count]
        )

        # Total size
        rows << table_row(
          "Total Size",
          "#{java_meta[:total_size_kb]} KB",
          "#{ruby_meta[:total_size_kb]} KB",
          (java_meta[:total_size_kb] - ruby_meta[:total_size_kb]).abs < 1
        )

        # Generation time (if available)
        if java_meta[:generation_time] && ruby_meta[:generation_time]
          rows << table_row(
            "Generation Time",
            "#{java_meta[:generation_time]}s",
            "#{ruby_meta[:generation_time]}s",
            nil
          )
        end

        # Symbol counts (sum across all files)
        symbol_types = [
          ["Total Symbols", :total_symbols],
          ["Elements", :elements],
          ["Optional Elements", :optional_elements],
          ["Attributes", :attributes],
          ["Sequences", :sequences],
          ["Choices", :choices],
          ["All Compositors", :all_compositors],
          ["Keys", :keys],
          ["Key References", :keyrefs],
          ["Unique Constraints", :uniques],
          ["Loops", :loops]
        ]

        symbol_types.each do |label, key|
          java_total = sum_symbol_count(java_meta[:files], key)
          ruby_total = sum_symbol_count(ruby_meta[:files], key)

          next if java_total == 0 && ruby_total == 0

          rows << table_row(label, java_total, ruby_total, java_total == ruby_total)
        end

        <<~HTML
          <table>
            <thead>
              <tr>
                <th>Metric</th>
                <th>Java XsdVi</th>
                <th>Ruby XsdVi</th>
                <th>Match</th>
              </tr>
            </thead>
            <tbody>
              #{rows.join("\n      ")}
            </tbody>
          </table>
        HTML
      end

      # Generate a table row
      # @param label [String] Row label
      # @param java_val [Object] Java value
      # @param ruby_val [Object] Ruby value
      # @param match [Boolean, nil] Whether values match (nil for N/A)
      # @return [String] HTML table row
      def table_row(label, java_val, ruby_val, match)
        match_cell = if match.nil?
                       "<td>—</td>"
                     elsif match
                       "<td class='match'>✓</td>"
                     else
                       "<td class='mismatch'>✗</td>"
                     end

        <<~HTML.strip
          <tr>
                <td><strong>#{label}</strong></td>
                <td>#{java_val}</td>
                <td>#{ruby_val}</td>
                #{match_cell}
              </tr>
        HTML
      end

      # Sum symbol counts across files
      # @param files [Array<Hash>] File metadata array
      # @param key [Symbol] Symbol type key
      # @return [Integer] Total count
      def sum_symbol_count(files, key)
        return 0 unless files

        files.sum { |f| f[key] || 0 }
      end

      # Generate element selector dropdown
      # @param java_meta [Hash] Java metadata
      # @param ruby_meta [Hash] Ruby metadata
      # @return [String] HTML select element or empty string
      def generate_element_selector(java_meta, ruby_meta)
        return "" if java_meta[:file_count] <= 1

        options = java_meta[:files].each_with_index.map do |file, index|
          name = File.basename(file[:name], ".svg")
          "<option value='#{index}'>#{name}</option>"
        end

        <<~HTML
          <div class="element-selector">
            <label for="element-select">Select Element:</label>
            <select id="element-select" onchange="loadFile(this.value)">
              #{options.join("\n      ")}
            </select>
          </div>
        HTML
      end
    end
  end
end