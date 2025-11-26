# frozen_string_literal: true

require "open-uri"
require "fileutils"

module Xsdvi
  module Comparison
    # Manages downloading, caching, and executing Java XsdVi
    class JavaManager
      JAR_URL = "https://github.com/metanorma/xsdvi/releases/download/v1.3/xsdvi-1.3.jar"
      CACHE_DIR = File.expand_path("~/.xsdvi")
      JAR_FILENAME = "xsdvi-1.3.jar"
      JAR_PATH = File.join(CACHE_DIR, JAR_FILENAME)
      EXPECTED_SIZE = 2_500_000 # ~2.5MB minimum

      def initialize
        @jar_path = JAR_PATH
      end

      # Ensure JAR is available, download if needed
      # @return [Boolean] true if JAR is ready
      def ensure_jar_available
        return true if jar_valid?

        puts "Downloading Java XsdVi v1.3..."
        download_jar
        verify_jar
        true
      end

      # Generate SVG using Java XsdVi
      # @param xsd_file [String] Path to XSD file
      # @param output_dir [String] Output directory path
      # @param options [Hash] Generation options
      # @option options [String] :root Root element name
      # @option options [Boolean] :all Generate all elements
      # @return [Boolean] true if successful
      def generate(xsd_file, output_dir, options = {})
        ensure_java_available
        ensure_jar_available

        cmd = build_java_command(xsd_file, output_dir, options)
        puts "Executing Java XsdVi..."

        success = system(cmd)
        raise "Java XsdVi execution failed" unless success

        true
      end

      private

      # Check if cached JAR is valid
      # @return [Boolean] true if JAR exists and has valid size
      def jar_valid?
        File.exist?(@jar_path) && File.size(@jar_path) > EXPECTED_SIZE
      end

      # Download JAR from GitHub releases
      def download_jar
        FileUtils.mkdir_p(CACHE_DIR)

        begin
          URI.open(JAR_URL, "rb") do |remote|
            File.binwrite(@jar_path, remote.read)
          end
        rescue StandardError => e
          raise "Failed to download Java XsdVi: #{e.message}"
        end
      end

      # Verify downloaded JAR integrity
      def verify_jar
        unless File.size(@jar_path) > EXPECTED_SIZE
          File.delete(@jar_path)
          raise "Downloaded JAR is invalid (size: #{File.size(@jar_path)} bytes)"
        end

        puts "✓ Java XsdVi cached at #{@jar_path}"
      end

      # Build Java command line
      # @param xsd_file [String] Path to XSD file
      # @param output_dir [String] Output directory path
      # @param options [Hash] Generation options
      # @return [String] Complete command string
      def build_java_command(xsd_file, output_dir, options)
        cmd_parts = ["java", "-jar", @jar_path]

        # Input file is positional (no --in flag)
        cmd_parts << File.expand_path(xsd_file)

        # Root node name (including "all" for generating all elements)
        if options[:root]
          cmd_parts << "-rootNodeName" << options[:root]
        end

        # One node only flag (required when generating all elements separately)
        cmd_parts << "-oneNodeOnly" if options[:root] == "all"

        # Output path
        cmd_parts << "-outputPath" << File.expand_path(output_dir)

        cmd_parts.join(" ")
      end

      # Check if Java is available on system
      # @raise [RuntimeError] if Java is not installed
      def ensure_java_available
        return if system("java -version", out: File::NULL, err: File::NULL)

        raise <<~ERROR
          Error: Java is required but not installed.

          Please install Java from: https://java.com
          Or use your system package manager:
            - macOS: brew install openjdk
            - Ubuntu/Debian: sudo apt-get install default-jdk
            - Fedora: sudo dnf install java-latest-openjdk
        ERROR
      end
    end
  end
end
