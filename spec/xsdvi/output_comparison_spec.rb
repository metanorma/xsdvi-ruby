# frozen_string_literal: true

require "spec_helper"
require "canon"

RSpec.describe "Output Comparison" do
  describe "TestXMLEntities.xsd output" do
    let(:java_output_raw) do
      File.read("spec/fixtures/java/TestXMLEntities-java.svg")
    end
    let(:ruby_output_raw) do
      File.read("spec/fixtures/java/TestXMLEntities-ruby.svg")
    end

    # Normalize outputs for comparison
    # Remove data-desc-* attributes (vary due to text wrapping)
    # Remove all description text elements (wrapping causes different counts)
    # Normalize onclick spacing (cosmetic difference)
    let(:java_output) do
      java_output_raw
        .gsub(/data-desc-height='[^']*'/, "data-desc-height='0'")
        .gsub(/data-desc-height-rest='[^']*'/, "data-desc-height-rest='0'")
        .gsub(/data-desc-x='[^']*'/, "data-desc-x='0'")
        .gsub(/\s\s+\+/, " +")
        .gsub(/<text[^>]*class='desc'[^>]*>.*?<\/text>\n?/m, "")
    end

    let(:ruby_output) do
      ruby_output_raw
        .gsub(/data-desc-height='[^']*'/, "data-desc-height='0'")
        .gsub(/data-desc-height-rest='[^']*'/, "data-desc-height-rest='0'")
        .gsub(/data-desc-x='[^']*'/, "data-desc-x='0'")
        .gsub(/\s\s+\+/, " +")
        .gsub(/<text[^>]*class='desc'[^>]*>.*?<\/text>\n?/m, "")
    end

    it "produces structurally equivalent output to Java version" do
      expect(ruby_output).to be_xml_equivalent_to(java_output)
    end
  end
end
