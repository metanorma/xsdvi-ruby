# frozen_string_literal: true

require "spec_helper"

RSpec.describe Xsdvi::Tree::Element do
  let(:element) { described_class.new }
  let(:child) { described_class.new }
  let(:parent) { described_class.new }

  describe "#initialize" do
    it "initializes with empty children" do
      expect(element.children).to be_empty
    end

    it "initializes without a parent" do
      expect(element.parent).to be_nil
    end
  end

  describe "#add_child" do
    it "adds a child to the element" do
      element.add_child(child)
      expect(element.children).to include(child)
    end
  end

  describe "#parent?" do
    it "returns false when no parent" do
      expect(element.parent?).to be false
    end

    it "returns true when parent is set" do
      element.parent = parent
      expect(element.parent?).to be true
    end
  end

  describe "#children?" do
    it "returns false when no children" do
      expect(element.children?).to be false
    end

    it "returns true when children exist" do
      element.add_child(child)
      expect(element.children?).to be true
    end
  end

  describe "#first_child?" do
    it "returns true when element is first child" do
      parent.add_child(element)
      parent.add_child(child)
      element.parent = parent
      expect(element.first_child?).to be true
    end

    it "returns false when element is not first child" do
      parent.add_child(child)
      parent.add_child(element)
      element.parent = parent
      expect(element.first_child?).to be false
    end
  end

  describe "#last_child?" do
    it "returns true when element is last child" do
      parent.add_child(child)
      parent.add_child(element)
      element.parent = parent
      expect(element.last_child?).to be true
    end

    it "returns false when element is not last child" do
      parent.add_child(element)
      parent.add_child(child)
      element.parent = parent
      expect(element.last_child?).to be false
    end
  end

  describe "#code" do
    it "returns code for root element" do
      expect(element.code).to eq("_1")
    end

    it "returns code for nested elements" do
      parent.add_child(element)
      element.parent = parent
      expect(element.code).to eq("_1_1")
    end
  end
end
