# frozen_string_literal: true

module Xsdvi
  module Utils
    # Helper class for loading resource files
    class ResourceLoader
      def read_resource_file(resource_file)
        resource_path = File.join(
          File.dirname(__FILE__),
          "../../..",
          "resources",
          resource_file,
        )
        File.read(resource_path)
      rescue Errno::ENOENT => e
        warn "Resource file not found: #{resource_path}"
        raise e
      end
    end
  end
end
