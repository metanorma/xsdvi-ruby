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

      # Type registries for resolution (Phase 1)
      @complex_types = {}      # QName => complexType node
      @simple_types = {}       # QName => simpleType node
      @model_groups = {}       # QName => group node
      @attribute_groups = {}   # QName => attributeGroup node
      @elements = {}           # QName => element node (for refs)
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

      # Phase 1: Collect all type definitions, groups, and elements
      collect_type_definitions(doc)
      collect_group_definitions(doc)
      collect_attribute_group_definitions(doc)
      collect_element_definitions(doc)

      # Create schema symbol when no root node specified (matches Java line 65-68)
      if root_node_name.nil?
        symbol = SVG::Symbols::Schema.new
        builder.set_root(symbol)
      end

      # Phase 2: Process elements with type resolution
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

    def collect_type_definitions(doc)
      # Collect complexType definitions
      doc.xpath("//xs:complexType[@name]", "xs" => XSD_NAMESPACE).each do |node|
        name = node["name"]
        @complex_types[name] = node
      end

      # Collect simpleType definitions
      doc.xpath("//xs:simpleType[@name]", "xs" => XSD_NAMESPACE).each do |node|
        name = node["name"]
        @simple_types[name] = node
      end
    end

    def collect_group_definitions(doc)
      doc.xpath("//xs:group[@name]", "xs" => XSD_NAMESPACE).each do |node|
        name = node["name"]
        @model_groups[name] = node
      end
    end

    def collect_attribute_group_definitions(doc)
      doc.xpath("//xs:attributeGroup[@name]", "xs" => XSD_NAMESPACE).each do |node|
        name = node["name"]
        @attribute_groups[name] = node
      end
    end

    def collect_element_definitions(doc)
      doc.xpath("//xs:element[@name]", "xs" => XSD_NAMESPACE).each do |node|
        name = node["name"]
        @elements[name] = node
      end
    end

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
      # Phase 5: Handle element references first
      if (ref = elem_node["ref"])
        process_element_ref(ref, cardinality)
        return
      end

      name = elem_node["name"]
      elem_namespace = elem_node["namespace"]
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
        # Check for inline complexType first
        complex_type = elem_node.at_xpath("xs:complexType",
                                          "xs" => XSD_NAMESPACE)
        if complex_type
          # Process inline anonymous complexType
          process_complex_type_node(complex_type)
        elsif type_attr
          # Try to resolve type reference
          resolved_type = resolve_type(type_attr)
          if resolved_type
            # Process the resolved named type
            if resolved_type.name == "complexType"
              process_complex_type_node(resolved_type)
            elsif resolved_type.name == "simpleType"
              # simpleTypes don't have children to process
              # The type string is already set above
            end
          elsif type_attr == "anyType"
            # Explicit anyType reference
            process_any_type_default
          end
          # If type is built-in (string, int, etc), we just show the type string
        else
          # No type means anyType - expand it
          process_any_type_default
        end
      end

      @stack.pop
      # Process identity constraints (matches Java line 262)
      process_identity_constraints(elem_node)
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
      # Phase 6: Check for complexContent or simpleContent first
      complex_content = complex_type_node.at_xpath("xs:complexContent",
                                                    "xs" => XSD_NAMESPACE)
      simple_content = complex_type_node.at_xpath("xs:simpleContent",
                                                   "xs" => XSD_NAMESPACE)

      if complex_content
        process_complex_content(complex_content)
      elsif simple_content
        process_simple_content(simple_content)
      else
        # Direct content model (no extension/restriction wrapper)
        process_complex_type_content(complex_type_node)
      end
    end

    # Phase 6: Process complexContent
    def process_complex_content(complex_content_node)
      extension = complex_content_node.at_xpath("xs:extension",
                                                "xs" => XSD_NAMESPACE)
      restriction = complex_content_node.at_xpath("xs:restriction",
                                                  "xs" => XSD_NAMESPACE)

      if extension
        process_extension(extension)
      elsif restriction
        process_restriction(restriction)
      end
    end

    # Phase 6: Process simpleContent
    def process_simple_content(simple_content_node)
      extension = simple_content_node.at_xpath("xs:extension",
                                               "xs" => XSD_NAMESPACE)
      restriction = simple_content_node.at_xpath("xs:restriction",
                                                 "xs" => XSD_NAMESPACE)

      if extension
        process_extension(extension)
      elsif restriction
        process_restriction(restriction)
      end
    end

    # Phase 6: Process extension
    def process_extension(extension_node)
      # Process base type first (inherit content model)
      if (base = extension_node["base"])
        base_type = resolve_type(base)
        process_complex_type_node(base_type) if base_type && base_type.name == "complexType"
      end

      # Then process extension's own content
      process_complex_type_content(extension_node)
    end

    # Phase 6: Process restriction
    def process_restriction(restriction_node)
      # Process base type first (inherit and potentially restrict content model)
      if (base = restriction_node["base"])
        base_type = resolve_type(base)
        process_complex_type_node(base_type) if base_type && base_type.name == "complexType"
      end

      # Then process restriction's own content
      process_complex_type_content(restriction_node)
    end

    # Phase 6: Process complex type content (particles and attributes)
    def process_complex_type_content(node)
      # Process particles (sequence/choice/all)
      sequence = node.at_xpath("xs:sequence", "xs" => XSD_NAMESPACE)
      process_sequence(sequence, nil) if sequence

      choice = node.at_xpath("xs:choice", "xs" => XSD_NAMESPACE)
      process_choice(choice, nil) if choice

      all_node = node.at_xpath("xs:all", "xs" => XSD_NAMESPACE)
      process_all(all_node, nil) if all_node

      # Process attributes (both direct and references) - SORT ALPHABETICALLY
      attributes = node.xpath("xs:attribute", "xs" => XSD_NAMESPACE)
      sorted_attributes = attributes.sort_by do |attr|
        # Sort by ref or name
        attr["ref"] || attr["name"] || ""
      end
      sorted_attributes.each { |attr| process_attribute(attr) }

      # Process attribute group references
      attr_groups = node.xpath("xs:attributeGroup[@ref]", "xs" => XSD_NAMESPACE)
      attr_groups.each do |attr_group|
        process_attribute_group_ref(attr_group["ref"])
      end

      # Process attribute wildcard
      any_attr = node.at_xpath("xs:anyAttribute", "xs" => XSD_NAMESPACE)
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

      # Process group references (Phase 3)
      sequence_node.xpath("xs:group[@ref]", "xs" => XSD_NAMESPACE).each do |group|
        process_group_ref(group["ref"])
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

      # Process group references (Phase 3)
      choice_node.xpath("xs:group[@ref]", "xs" => XSD_NAMESPACE).each do |group|
        process_group_ref(group["ref"])
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

      # Process group references (Phase 3)
      all_node.xpath("xs:group[@ref]", "xs" => XSD_NAMESPACE).each do |group|
        process_group_ref(group["ref"])
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
      # Handle attribute references (like <xsd:attribute ref="xml:lang"/>)
      if (ref = attr_node["ref"])
        process_attribute_ref(ref, attr_node)
        return
      end

      symbol = SVG::Symbols::Attribute.new
      symbol.name = attr_node["name"]
      namespace = attr_node["namespace"]
      symbol.namespace = namespace if namespace && namespace != schema_namespace

      # Strip xsd: prefix from type display
      if attr_node["type"]
        type_value = attr_node["type"]
        type_value = type_value.sub(/^xsd:/, "") if type_value.start_with?("xsd:")
        symbol.type = "type: #{type_value}"
      end

      symbol.required = attr_node["use"] == "required"

      # Capture default or fixed values
      if attr_node["default"]
        symbol.constraint = "default: #{attr_node['default']}"
      elsif attr_node["fixed"]
        symbol.constraint = "fixed: #{attr_node['fixed']}"
      end

      symbol.description = extract_documentation(attr_node)

      builder.append_child(symbol)
      builder.level_up
    end

    # Process attribute reference
    def process_attribute_ref(ref, ref_node)
      # Extract namespace prefix and local name
      if ref.include?(":")
        prefix, local_name = ref.split(":", 2)
      else
        prefix = nil
        local_name = ref
      end

      symbol = SVG::Symbols::Attribute.new

      # Handle xml: namespace attributes specially
      if prefix == "xml"
        # W3C XML namespace
        symbol.namespace = "http://www.w3.org/XML/1998/namespace"
        symbol.name = local_name  # Just "lang" or "id", not "xml:lang" or "xml:id"

        # Set type based on specific xml: attribute
        case local_name
        when "id"
          symbol.type = "type: ID"
        when "lang"
          symbol.type = "base: anySimpleType"
        when "space"
          symbol.type = "type: NCName"
        when "base"
          symbol.type = "type: anyURI"
        else
          symbol.type = "base: anySimpleType"
        end
      else
        # Regular attribute reference - would need to look up in schema
        symbol.name = local_name
      end

      # Get use constraint from the reference location
      symbol.required = ref_node["use"] == "required"

      # Extract documentation from the reference node itself
      symbol.description = extract_documentation(ref_node)

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

    # Phase 3: Group reference resolution
    def process_group_ref(ref)
      return unless ref

      # Strip namespace prefix if present
      group_name = ref.include?(":") ? ref.split(":").last : ref
      group_node = @model_groups[group_name]

      return unless group_node

      # Process the referenced group's content (sequence, choice, or all)
      model_group = group_node.at_xpath("xs:sequence | xs:choice | xs:all",
                                        "xs" => XSD_NAMESPACE)
      return unless model_group

      case model_group.name
      when "sequence"
        process_sequence(model_group, nil)
      when "choice"
        process_choice(model_group, nil)
      when "all"
        process_all(model_group, nil)
      end
    end

    # Phase 4: Attribute group reference resolution
    def process_attribute_group_ref(ref)
      return unless ref

      # Strip namespace prefix if present
      group_name = ref.include?(":") ? ref.split(":").last : ref
      group_node = @attribute_groups[group_name]

      return unless group_node

      # Process all attributes in the group
      group_node.xpath("xs:attribute", "xs" => XSD_NAMESPACE).each do |attr|
        process_attribute(attr)
      end

      # Process nested attribute group references (can be recursive)
      group_node.xpath("xs:attributeGroup[@ref]", "xs" => XSD_NAMESPACE).each do |nested|
        process_attribute_group_ref(nested["ref"])
      end
    end

    # Phase 5: Element reference resolution
    def process_element_ref(ref, cardinality)
      return unless ref

      # Strip namespace prefix if present
      elem_name = ref.include?(":") ? ref.split(":").last : ref
      elem_node = @elements[elem_name]

      return unless elem_node

      # Check for circular reference to prevent infinite recursion
      if @stack.any? { |e| e["name"] == elem_name }
        # Create a loop symbol instead (Loop doesn't have a name attribute)
        symbol = SVG::Symbols::Loop.new
        builder.append_child(symbol)
        builder.level_up
        return
      end

      # Process the referenced element
      process_element_declaration(elem_node, cardinality, false)
    end

    def process_loop?(elem_node)
      @stack.any?(elem_node)
    end

    def get_cardinality(node)
      min_occurs = node["minOccurs"]&.to_i || 1
      max_occurs_str = node["maxOccurs"] || "1"  # XSD default is "1" when not specified

      return nil if min_occurs == 1 && max_occurs_str == "1"

      if max_occurs_str == "unbounded"
        "#{min_occurs}..∞"
      else
        max_occurs = max_occurs_str.to_i
        "#{min_occurs}..#{max_occurs}"
      end
    end

    def extract_documentation(node)
      docs = node.xpath(
        "./xs:annotation/xs:documentation",  # Changed from .// to ./ (direct children only)
        "xs" => XSD_NAMESPACE,
      )
      # Use inner_html to preserve XML entities like &lt; and &gt;
      # Java's XML parser preserves these, affecting wrap length calculations
      docs.map(&:inner_html).map { |text| text.gsub(/\n[ \t]+/, "\n") }
    end

    # Phase 2: Type resolution methods
    def resolve_type(type_attr)
      return nil unless type_attr

      # Strip namespace prefix if present (e.g., "xs:string" -> "string")
      type_name = type_attr.include?(":") ? type_attr.split(":").last : type_attr

      # Don't try to resolve built-in XSD types
      return nil if is_builtin_type?(type_name)

      # Look up in registries
      @complex_types[type_name] || @simple_types[type_name]
    end

    def is_builtin_type?(type_name)
      # W3C XML Schema built-in types
      %w[
        string boolean decimal float double duration dateTime
        time date gYearMonth gYear gMonthDay gDay gMonth
        hexBinary base64Binary anyURI QName NOTATION
        normalizedString token language NMTOKEN NMTOKENS
        Name NCName ID IDREF IDREFS ENTITY ENTITIES
        integer nonPositiveInteger negativeInteger long int
        short byte nonNegativeInteger unsignedLong unsignedInt
        unsignedShort unsignedByte positiveInteger
        anyType anySimpleType anyAtomicType
      ].include?(type_name)
    end

    def process_identity_constraints(elem_node)
      # Process xs:key
      elem_node.xpath("xs:key", "xs" => XSD_NAMESPACE).each do |constraint|
        process_identity_constraint(constraint, :key)
      end

      # Process xs:keyref
      elem_node.xpath("xs:keyref", "xs" => XSD_NAMESPACE).each do |constraint|
        process_identity_constraint(constraint, :keyref)
      end

      # Process xs:unique
      elem_node.xpath("xs:unique", "xs" => XSD_NAMESPACE).each do |constraint|
        process_identity_constraint(constraint, :unique)
      end
    end

    def process_identity_constraint(constraint_node, category)
      # Create appropriate symbol based on category
      symbol = case category
               when :key
                 SVG::Symbols::Key.new
               when :keyref
                 SVG::Symbols::Keyref.new
               when :unique
                 SVG::Symbols::Unique.new
               end

      # Set common properties
      symbol.name = constraint_node["name"]
      namespace = constraint_node["namespace"]
      symbol.namespace = namespace if namespace && namespace != schema_namespace
      symbol.description = extract_documentation(constraint_node)

      # For keyref, set the refer attribute
      if category == :keyref
        symbol.refer = constraint_node["refer"]
      end

      builder.append_child(symbol)

      # Process selector
      selector_node = constraint_node.at_xpath("xs:selector", "xs" => XSD_NAMESPACE)
      if selector_node
        selector_symbol = SVG::Symbols::Selector.new
        selector_symbol.xpath = selector_node["xpath"]
        builder.append_child(selector_symbol)
        builder.level_up
      end

      # Process field(s)
      constraint_node.xpath("xs:field", "xs" => XSD_NAMESPACE).each do |field_node|
        field_symbol = SVG::Symbols::Field.new
        field_symbol.xpath = field_node["xpath"]
        builder.append_child(field_symbol)
        builder.level_up
      end

      builder.level_up
    end
  end
end
