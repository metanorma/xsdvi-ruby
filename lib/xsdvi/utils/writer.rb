# frozen_string_literal: true

module Xsdvi
  module Utils
    # Helper class for writing output files
    class Writer
      DEFAULT_CHARSET = "UTF-8"

      attr_reader :writer

      def initialize(uri = nil, charset_name = DEFAULT_CHARSET)
        new_writer(uri, charset_name) if uri
      end

      def close
        writer&.close
      end

      def append(content)
        writer&.write(content)
        writer
      end

      def new_writer(uri, charset_name = DEFAULT_CHARSET)
        @writer = File.open(uri, "w:#{charset_name}")
      end
    end
  end
end
