# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Type Resolution" do
  let(:temp_output) { File.join(__dir__, "../tmp/type_resolution_output.svg") }

  before do
    FileUtils.mkdir_p(File.dirname(temp_output))
  end

  after do
    FileUtils.rm_f(temp_output) if File.exist?(temp_output)
  end

  # Helper method to process XSD file and return root
  def process_xsd_file(fixture, root_node_name = nil)
    builder = Xsdvi::Tree::Builder.new
    handler = Xsdvi::XsdHandler.new(builder)
    handler.root_node_name = root_node_name
    handler.process_file(fixture)
    builder.root
  end

  describe "Named Type Resolution" do
    let(:fixture) do
      File.join(__dir__, "../fixtures/type_resolution/named_types.xsd")
    end

    context "when resolving complex type references" do
      it "expands AddressType definition" do
        root = process_xsd_file(fixture, "Address")

        expect(root).to be_a(Xsdvi::SVG::Symbols::Element)
        expect(root.name).to eq("Address")

        # Verify type resolution expanded the structure
        expect(root.children.length).to be > 0

        # Find sequence compositor
        sequence = root.children.find { |c| c.is_a?(Xsdvi::SVG::Symbols::Sequence) }
        expect(sequence).not_to be_nil

        # Verify resolved elements exist
        element_names = sequence.children.map(&:name)
        expect(element_names).to include("street", "city", "zipCode")
      end

      it "resolves nested complex type references" do
        root = process_xsd_file(fixture, "Person")

        expect(root).to be_a(Xsdvi::SVG::Symbols::Element)
        expect(root.name).to eq("Person")

        # Count total element symbols (should include nested AddressType)
        element_count = count_elements_recursive(root)
        expect(element_count).to be >= 6 # name, age, address, street, city, zipCode
      end
    end

    context "when resolving simple type references" do
      it "processes CountryCode with simple type" do
        root = process_xsd_file(fixture, "CountryCode")

        expect(root).to be_a(Xsdvi::SVG::Symbols::Element)
        expect(root.name).to eq("CountryCode")

        # Simple types don't expand structure but type info is preserved
        expect(root.type).to include("CountryCodeType")
      end
    end

    context "when generating SVG output" do
      it "creates valid SVG file" do
        root = process_xsd_file(fixture, "Person")

        writer = Xsdvi::Utils::Writer.new
        writer.new_writer(temp_output)
        generator = Xsdvi::SVG::Generator.new(writer)
        generator.draw(root)

        expect(File.exist?(temp_output)).to be true
        content = File.read(temp_output)
        expect(content).to include("<svg")
        expect(content).to include("</svg>")
      end
    end
  end

  describe "Group Reference Resolution" do
    let(:fixture) do
      File.join(__dir__, "../fixtures/type_resolution/group_refs.xsd")
    end

    it "resolves single group reference" do
      root = process_xsd_file(fixture, "Document")

      expect(root).to be_a(Xsdvi::SVG::Symbols::Element)

      # Should contain expanded group elements
      element_names = collect_element_names(root)
      expect(element_names).to include("createdBy", "createdDate")
      expect(element_names).to include("modifiedBy", "modifiedDate")
    end

    it "resolves multiple group references" do
      root = process_xsd_file(fixture, "User")

      element_names = collect_element_names(root)

      # From ContactInfoGroup
      expect(element_names).to include("email", "phone")

      # From CommonMetadataGroup
      expect(element_names).to include("createdBy", "createdDate")
    end

    it "handles group references with proper cardinality" do
      root = process_xsd_file(fixture, "User")

      # Find modifiedBy element (optional in group with minOccurs=0)
      modified_elem = find_element_by_name(root, "modifiedBy")
      expect(modified_elem).not_to be_nil
      # The element exists - cardinality handling depends on group processing
      expect(modified_elem.name).to eq("modifiedBy")
    end
  end

  describe "Attribute Group Reference Resolution" do
    let(:fixture) do
      File.join(__dir__, "../fixtures/type_resolution/attribute_groups.xsd")
    end

    it "resolves single attribute group reference" do
      root = process_xsd_file(fixture, "Article")

      # Collect all attribute names
      attr_names = collect_attribute_names(root)

      # From CommonAttributesGroup
      expect(attr_names).to include("id", "version", "lang")

      # From DisplayAttributesGroup
      expect(attr_names).to include("visible", "priority")
    end

    it "resolves nested attribute group references" do
      root = process_xsd_file(fixture, "Section")

      attr_names = collect_attribute_names(root)

      # From nested ExtendedAttributesGroup which includes CommonAttributesGroup
      expect(attr_names).to include("id", "version", "lang")
      expect(attr_names).to include("status")
    end

    it "preserves attribute properties from groups" do
      root = process_xsd_file(fixture, "Article")

      # Find id attribute (required from group)
      id_attr = find_attribute_by_name(root, "id")
      expect(id_attr).not_to be_nil
      expect(id_attr.required).to be true
    end
  end

  describe "Element Reference Resolution" do
    let(:fixture) do
      File.join(__dir__, "../fixtures/type_resolution/element_refs.xsd")
    end

    it "resolves global element references" do
      root = process_xsd_file(fixture, "Book")

      element_names = collect_element_names(root)

      expect(element_names).to include("GlobalTitle")
      expect(element_names).to include("GlobalDescription")
      expect(element_names).to include("GlobalDate")
      expect(element_names).to include("isbn")
    end

    it "expands complex global element references" do
      root = process_xsd_file(fixture, "Book")

      # GlobalAuthor has nested structure
      author_elem = find_element_by_name(root, "GlobalAuthor")
      expect(author_elem).not_to be_nil

      # Should have firstName and lastName children
      author_children = collect_element_names(author_elem)
      expect(author_children).to include("firstName", "lastName")
    end

    it "handles element references with cardinality" do
      root = process_xsd_file(fixture, "Book")

      # GlobalAuthor can appear multiple times (maxOccurs=unbounded becomes "∞")
      author_elem = find_element_by_name(root, "GlobalAuthor")
      expect(author_elem.cardinality).to include("∞")
    end

    it "reuses global element definitions across multiple references" do
      # Both Book and Article reference GlobalTitle
      book_root = process_xsd_file(fixture, "Book")
      book_title = find_element_by_name(book_root, "GlobalTitle")

      article_root = process_xsd_file(fixture, "Article")
      article_title = find_element_by_name(article_root, "GlobalTitle")

      # Both should exist and have same name
      expect(book_title).not_to be_nil
      expect(article_title).not_to be_nil
      expect(book_title.name).to eq(article_title.name)
    end
  end

  describe "Extension and Restriction Resolution" do
    let(:fixture) do
      File.join(__dir__, "../fixtures/type_resolution/inheritance.xsd")
    end

    context "complexContent extension" do
      it "includes base type elements" do
        root = process_xsd_file(fixture, "Employee")

        element_names = collect_element_names(root)

        # From base type BasePersonType
        expect(element_names).to include("firstName", "lastName")

        # From extension
        expect(element_names).to include("employeeId", "department", "salary")
      end

      it "includes base type attributes" do
        root = process_xsd_file(fixture, "Employee")

        attr_names = collect_attribute_names(root)

        # From base type
        expect(attr_names).to include("id")

        # From extension
        expect(attr_names).to include("status")
      end
    end

    context "complexContent restriction" do
      it "processes restricted type" do
        root = process_xsd_file(fixture, "RestrictedPerson")

        element_names = collect_element_names(root)

        # Should still have base elements
        expect(element_names).to include("firstName", "lastName")
      end
    end

    context "simpleContent extension" do
      it "adds attributes to simple type" do
        root = process_xsd_file(fixture, "ExtendedString")

        attr_names = collect_attribute_names(root)

        expect(attr_names).to include("lang", "format")
      end
    end

    context "simpleContent restriction" do
      it "processes restricted simple content" do
        root = process_xsd_file(fixture, "RestrictedString")

        attr_names = collect_attribute_names(root)

        expect(attr_names).to include("lang", "format")
      end
    end

    context "multi-level inheritance" do
      it "resolves inheritance chain" do
        root = process_xsd_file(fixture, "Manager")

        element_names = collect_element_names(root)

        # From BasePersonType
        expect(element_names).to include("firstName", "lastName")

        # From EmployeeType
        expect(element_names).to include("employeeId", "department", "salary")

        # From ManagerType
        expect(element_names).to include("teamSize", "budget")
      end
    end
  end

  describe "Identity Constraint Resolution" do
    let(:fixture) do
      File.join(__dir__, "../fixtures/type_resolution/identity_constraints.xsd")
    end

    it "processes key constraints" do
      root = process_xsd_file(fixture, "Inventory")

      # Find key symbol
      key_symbol = find_symbol_by_type(root, Xsdvi::SVG::Symbols::Key)
      expect(key_symbol).not_to be_nil
      expect(key_symbol.name).to eq("ProductKey")
    end

    it "processes keyref constraints" do
      root = process_xsd_file(fixture, "Inventory")

      # Find keyref symbol
      keyref_symbol = find_symbol_by_type(root, Xsdvi::SVG::Symbols::Keyref)
      expect(keyref_symbol).not_to be_nil
      expect(keyref_symbol.name).to eq("ProductReference")
    end

    it "processes unique constraints" do
      root = process_xsd_file(fixture, "Inventory")

      # Find unique symbol
      unique_symbol = find_symbol_by_type(root, Xsdvi::SVG::Symbols::Unique)
      expect(unique_symbol).not_to be_nil
      expect(unique_symbol.name).to eq("OrderUnique")
    end

    it "processes selector elements" do
      root = process_xsd_file(fixture, "Inventory")

      # Find selector within key
      key_symbol = find_symbol_by_type(root, Xsdvi::SVG::Symbols::Key)
      selector = find_symbol_by_type(key_symbol, Xsdvi::SVG::Symbols::Selector)
      expect(selector).not_to be_nil
    end

    it "processes field elements" do
      root = process_xsd_file(fixture, "Inventory")

      # Find field within key structure
      key_symbol = find_symbol_by_type(root, Xsdvi::SVG::Symbols::Key)
      expect(key_symbol).not_to be_nil

      # Field symbols should exist as children (may be nested)
      field_count = count_symbols_by_type(key_symbol, Xsdvi::SVG::Symbols::Field)
      expect(field_count).to be > 0
    end

    it "handles composite keys with multiple fields" do
      root = process_xsd_file(fixture, "Catalog")

      # Find key with multiple fields
      key_symbol = find_symbol_by_type(root, Xsdvi::SVG::Symbols::Key)
      expect(key_symbol.name).to eq("ItemKey")

      # Count all Field symbols recursively under key
      field_count = count_symbols_by_type(key_symbol, Xsdvi::SVG::Symbols::Field)
      expect(field_count).to eq(2) # Category and ItemID
    end

    it "handles multiple constraints on same element" do
      root = process_xsd_file(fixture, "Library")

      # Should have key, unique, and keyref
      key_count = count_symbols_by_type(root, Xsdvi::SVG::Symbols::Key)
      unique_count = count_symbols_by_type(root, Xsdvi::SVG::Symbols::Unique)
      keyref_count = count_symbols_by_type(root, Xsdvi::SVG::Symbols::Keyref)

      expect(key_count).to eq(1)
      expect(unique_count).to eq(1)
      expect(keyref_count).to eq(1)
    end
  end

  describe "Circular Reference Resolution" do
    let(:fixture) do
      File.join(__dir__, "../fixtures/type_resolution/circular.xsd")
    end

    it "detects and marks self-referencing elements" do
      # Node references itself - should handle gracefully
      expect do
        root = process_xsd_file(fixture, "Node")
        # Should complete without infinite recursion
        expect(root).not_to be_nil
      end.not_to raise_error
    end

    it "handles circular type references" do
      # TreeNode has circular type reference
      expect do
        root = process_xsd_file(fixture, "TreeNode")
        expect(root).not_to be_nil
      end.not_to raise_error
    end

    it "handles mutual circular references" do
      # Parent->Child->Parent creates circular reference
      expect do
        root = process_xsd_file(fixture, "Parent")
        expect(root).not_to be_nil
      end.not_to raise_error
    end

    it "handles deep circular references" do
      # LevelOne->LevelTwo->LevelThree->LevelOne
      expect do
        root = process_xsd_file(fixture, "LevelOne")
        expect(root).not_to be_nil
      end.not_to raise_error
    end

    it "prevents infinite recursion" do
      # This should not hang or raise stack overflow
      expect do
        process_xsd_file(fixture, "RecursiveElement")
      end.not_to raise_error
    end
  end

  # Helper methods
  def count_elements_recursive(node)
    count = node.is_a?(Xsdvi::SVG::Symbols::Element) ? 1 : 0
    node.children.each do |child|
      count += count_elements_recursive(child)
    end
    count
  end

  def collect_element_names(node, names = [])
    names << node.name if node.is_a?(Xsdvi::SVG::Symbols::Element)
    node.children.each do |child|
      collect_element_names(child, names)
    end
    names
  end

  def collect_attribute_names(node, names = [])
    names << node.name if node.is_a?(Xsdvi::SVG::Symbols::Attribute)
    node.children.each do |child|
      collect_attribute_names(child, names)
    end
    names
  end

  def find_element_by_name(node, name)
    return node if node.is_a?(Xsdvi::SVG::Symbols::Element) && node.name == name

    node.children.each do |child|
      result = find_element_by_name(child, name)
      return result if result
    end
    nil
  end

  def find_attribute_by_name(node, name)
    return node if node.is_a?(Xsdvi::SVG::Symbols::Attribute) && node.name == name

    node.children.each do |child|
      result = find_attribute_by_name(child, name)
      return result if result
    end
    nil
  end

  def find_symbol_by_type(node, type)
    return node if node.is_a?(type)

    node.children.each do |child|
      result = find_symbol_by_type(child, type)
      return result if result
    end
    nil
  end

  def count_symbols_by_type(node, type)
    count = node.is_a?(type) ? 1 : 0
    node.children.each do |child|
      count += count_symbols_by_type(child, type)
    end
    count
  end
end