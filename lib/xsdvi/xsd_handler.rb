# frozen_string_literal: true

require "nokogiri"

module Xsdvi
  # Handles XSD parsing and tree building
  class XsdHandler
    XSD_NAMESPACE = "http://www.w3.org/2001/XMLSchema"

    attr_accessor :root_node_name, :one_node_only
    attr_reader :builder, :schema_namespace

    def initialize(builder)
      @builder = builder
      @stack = []
      @root_node_name = nil
      @one_node_only = false
      @schema_namespace = nil
    end

    def process_file(file_path)
      doc = Nokogiri::XML(File.read(file_path))
      process_model(doc)
    end

    def process_model(doc)
      return unless doc

      # Extract target namespace
      schema_node = doc.at_xpath("/xs:schema", "xs" => XSD_NAMESPACE)
      @schema_namespace = schema_node["targetNamespace"] if schema_node

      # Create schema symbol when no root node specified (matches Java line 65-68)
      if root_node_name.nil?
        symbol = SVG::Symbols::Schema.new
        builder.set_root(symbol)
      end

      process_element_declarations(doc)

      # Level up after processing all elements (matches Java line 71-73)
      builder.level_up if root_node_name.nil?
    end

    def get_elements_names(doc)
      elements = doc.xpath("//xs:schema/xs:element", "xs" => XSD_NAMESPACE)
      elements.filter_map { |elem| elem["name"] }
    end

    def set_schema_namespace(doc, element_name)
      elements = doc.xpath("//xs:schema/xs:element", "xs" => XSD_NAMESPACE)
      elements.each do |elem|
        if elem["name"] == element_name
          @schema_namespace = schema_node = doc.at_xpath("/xs:schema",
                                                         "xs" => XSD_NAMESPACE)
          @schema_namespace = schema_node["targetNamespace"] if schema_node
          break
        end
      end
    end

    private

    def process_element_declarations(doc)
      elements = doc.xpath("//xs:schema/xs:element", "xs" => XSD_NAMESPACE)

      elements.each do |elem|
        name = elem["name"]
        is_root = name == root_node_name
        if is_root || root_node_name.nil?
          process_element_declaration(elem, nil,
                                      is_root)
        end
      end
    end

    def process_element_declaration(elem_node, cardinality, is_root)
      name = elem_node["name"]
      elem_namespace = elem_node["namespace"]
      elem_node["ref"]
      type_attr = elem_node["type"]
      nillable = elem_node["nillable"] == "true"
      abstract = elem_node["abstract"] == "true"

      symbol = SVG::Symbols::Element.new
      symbol.name = name

      # Set namespace if different from schema namespace (matches Java line 228-231)
      if elem_namespace && elem_namespace != schema_namespace
        symbol.namespace = elem_namespace
      elsif schema_namespace && schema_namespace != elem_namespace
        # Show schema namespace on element when element doesn't override it
        symbol.namespace = schema_namespace
      end

      # Get type string (matches Java getTypeString logic)
      symbol.type = get_type_string(elem_node, type_attr)
      symbol.cardinality = cardinality
      symbol.nillable = nillable
      symbol.abstract = abstract
      symbol.description = extract_documentation(elem_node)
      symbol.start_y_position = 20 if is_root && one_node_only

      # Set root or append child (matches Java line 241-245)
      if is_root
        builder.set_root(symbol)
      else
        builder.append_child(symbol)
      end

      # Check for loops (matches Java line 247-250)
      if process_loop?(elem_node)
        builder.level_up
        return
      end

      @stack.push(elem_node)

      # Skip processing children if stack size > 1 and oneNodeOnly (matches Java line 253-260)
      unless @stack.size > 1 && one_node_only
        # Check if element has inline complexType
        complex_type = elem_node.at_xpath("xs:complexType",
                                          "xs" => XSD_NAMESPACE)
        if complex_type
          process_complex_type_node(complex_type)
        elsif !type_attr
          # No type means anyType - expand it
          process_any_type_default
        elsif type_attr == "anyType"
          process_any_type_default
        end
      end

      @stack.pop
      builder.level_up
    end

    def get_type_string(elem_node, type_attr)
      return "type: #{type_attr}" if type_attr

      # Check for inline simpleType or complexType
      complex_type = elem_node.at_xpath("xs:complexType", "xs" => XSD_NAMESPACE)
      simple_type = elem_node.at_xpath("xs:simpleType", "xs" => XSD_NAMESPACE)

      return nil if complex_type # Anonymous complex type

      if simple_type
        return "base: #{simple_type.at_xpath('xs:restriction',
                                             'xs' => XSD_NAMESPACE)['base']}"
      end

      "type: anyType" # Default
    end

    def process_any_type_default
      # anyType default content model: sequence containing 0..unbounded any and anyAttribute
      symbol = SVG::Symbols::Sequence.new
      symbol.cardinality = nil
      builder.append_child(symbol)

      # Add any element
      any_symbol = SVG::Symbols::Any.new
      any_symbol.namespace = "any NS"
      any_symbol.process_contents = SVG::Symbol::PC_LAX
      any_symbol.cardinality = "0..∞"
      builder.append_child(any_symbol)
      builder.level_up

      builder.level_up

      # Add anyAttribute
      any_attr_symbol = SVG::Symbols::AnyAttribute.new
      any_attr_symbol.namespace = "any NS"
      any_attr_symbol.process_contents = SVG::Symbol::PC_LAX
      builder.append_child(any_attr_symbol)
      builder.level_up
    end

    def process_complex_type_node(complex_type_node)
      # Process particles (sequence/choice/all)
      sequence = complex_type_node.at_xpath("xs:sequence",
                                            "xs" => XSD_NAMESPACE)
      process_sequence(sequence, nil) if sequence

      choice = complex_type_node.at_xpath("xs:choice", "xs" => XSD_NAMESPACE)
      process_choice(choice, nil) if choice

      all_node = complex_type_node.at_xpath("xs:all", "xs" => XSD_NAMESPACE)
      process_all(all_node, nil) if all_node

      # Process attributes
      attributes = complex_type_node.xpath("xs:attribute",
                                           "xs" => XSD_NAMESPACE)
      attributes.each { |attr| process_attribute(attr) }

      # Process attribute wildcard
      any_attr = complex_type_node.at_xpath("xs:anyAttribute",
                                            "xs" => XSD_NAMESPACE)
      process_any_attribute(any_attr) if any_attr
    end

    def process_sequence(sequence_node, cardinality)
      card = cardinality || get_cardinality(sequence_node)
      symbol = SVG::Symbols::Sequence.new
      symbol.cardinality = card
      symbol.description = extract_documentation(sequence_node)
      builder.append_child(symbol)

      # Process child elements
      sequence_node.xpath("xs:element", "xs" => XSD_NAMESPACE).each do |elem|
        process_element_declaration(elem, get_cardinality(elem), false)
      end

      # Process any
      sequence_node.xpath("xs:any", "xs" => XSD_NAMESPACE).each do |any|
        process_any(any)
      end

      builder.level_up
    end

    def process_choice(choice_node, cardinality)
      card = cardinality || get_cardinality(choice_node)
      symbol = SVG::Symbols::Choice.new
      symbol.cardinality = card
      symbol.description = extract_documentation(choice_node)
      builder.append_child(symbol)

      # Process child elements
      choice_node.xpath("xs:element", "xs" => XSD_NAMESPACE).each do |elem|
        process_element_declaration(elem, get_cardinality(elem), false)
      end

      builder.level_up
    end

    def process_all(all_node, cardinality)
      card = cardinality || get_cardinality(all_node)
      symbol = SVG::Symbols::All.new
      symbol.cardinality = card
      symbol.description = extract_documentation(all_node)
      builder.append_child(symbol)

      # Process child elements
      all_node.xpath("xs:element", "xs" => XSD_NAMESPACE).each do |elem|
        process_element_declaration(elem, get_cardinality(elem), false)
      end

      builder.level_up
    end

    def process_any(any_node)
      symbol = SVG::Symbols::Any.new
      namespace = any_node["namespace"]
      symbol.namespace = namespace || "any NS"
      process_contents = any_node["processContents"]
      symbol.process_contents = case process_contents
                                when "skip" then SVG::Symbol::PC_SKIP
                                when "lax" then SVG::Symbol::PC_LAX
                                when "strict" then SVG::Symbol::PC_STRICT
                                else SVG::Symbol::PC_LAX  # Default is lax for anyType
                                end
      symbol.cardinality = get_cardinality(any_node)
      symbol.description = extract_documentation(any_node)
      builder.append_child(symbol)
      builder.level_up
    end

    def process_attribute(attr_node)
      symbol = SVG::Symbols::Attribute.new
      symbol.name = attr_node["name"]
      namespace = attr_node["namespace"]
      symbol.namespace = namespace if namespace && namespace != schema_namespace
      symbol.type = attr_node["type"] ? "type: #{attr_node['type']}" : nil
      symbol.required = attr_node["use"] == "required"
      symbol.description = extract_documentation(attr_node)

      builder.append_child(symbol)
      builder.level_up
    end

    def process_any_attribute(any_attr_node)
      symbol = SVG::Symbols::AnyAttribute.new
      namespace = any_attr_node["namespace"]
      symbol.namespace = namespace || "any NS"
      process_contents = any_attr_node["processContents"]
      symbol.process_contents = case process_contents
                                when "skip" then SVG::Symbol::PC_SKIP
                                when "lax" then SVG::Symbol::PC_LAX
                                when "strict" then SVG::Symbol::PC_STRICT
                                else SVG::Symbol::PC_LAX  # Default is lax for anyType
                                end
      symbol.description = extract_documentation(any_attr_node)
      builder.append_child(symbol)
      builder.level_up
    end

    def process_loop?(elem_node)
      @stack.any?(elem_node)
    end

    def get_cardinality(node)
      min_occurs = node["minOccurs"]&.to_i || 1
      max_occurs = node["maxOccurs"]

      return nil if min_occurs == 1 && (max_occurs.nil? || max_occurs == "1")

      if max_occurs == "unbounded"
        "#{min_occurs}..∞"
      elsif max_occurs
        "#{min_occurs}..#{max_occurs}"
      end
    end

    def extract_documentation(node)
      docs = node.xpath(
        ".//xs:annotation/xs:documentation",
        "xs" => XSD_NAMESPACE,
      )
      docs.map(&:text).map { |text| text.gsub(/\n[ \t]+/, "\n") }
    end
  end
end
