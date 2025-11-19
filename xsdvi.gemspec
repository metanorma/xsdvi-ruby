# frozen_string_literal: true

require_relative "lib/xsdvi/version"

Gem::Specification.new do |spec|
  spec.name          = "xsdvi"
  spec.version       = Xsdvi::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "Generate SVG diagrams from XSD schemas"
  spec.description   = "Ruby port of XsdVi - transforms W3C XML Schema " \
                       "instances into interactive SVG diagrams"
  spec.homepage      = "https://github.com/metanorma/xsdvi-ruby"
  spec.license       = "BSD-3-Clause"

  spec.required_ruby_version = ">= 3.0.0"

  spec.files         = Dir["lib/**/*", "exe/*", "resources/**/*",
                           "README.adoc", "LICENSE"]
  spec.bindir        = "exe"
  spec.executables   = ["xsdvi"]
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri", "~> 1.16"
  spec.add_dependency "thor", "~> 1.3"

  spec.metadata["rubygems_mfa_required"] = "true"
end
