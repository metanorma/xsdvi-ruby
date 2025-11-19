# frozen_string_literal: true

require_relative "xsdvi/version"
require_relative "xsdvi/cli"
require_relative "xsdvi/xsd_handler"
require_relative "xsdvi/tree/element"
require_relative "xsdvi/tree/builder"
require_relative "xsdvi/svg/generator"
require_relative "xsdvi/svg/symbol"
require_relative "xsdvi/svg/symbols/all"
require_relative "xsdvi/svg/symbols/any"
require_relative "xsdvi/svg/symbols/any_attribute"
require_relative "xsdvi/svg/symbols/attribute"
require_relative "xsdvi/svg/symbols/choice"
require_relative "xsdvi/svg/symbols/element"
require_relative "xsdvi/svg/symbols/field"
require_relative "xsdvi/svg/symbols/key"
require_relative "xsdvi/svg/symbols/keyref"
require_relative "xsdvi/svg/symbols/loop"
require_relative "xsdvi/svg/symbols/schema"
require_relative "xsdvi/svg/symbols/selector"
require_relative "xsdvi/svg/symbols/sequence"
require_relative "xsdvi/svg/symbols/unique"
require_relative "xsdvi/utils/writer"
require_relative "xsdvi/utils/resource_loader"
require_relative "xsdvi/utils/width_calculator"

module Xsdvi
  class Error < StandardError; end
end
