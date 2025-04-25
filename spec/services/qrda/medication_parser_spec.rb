require "nokogiri"
require_relative "../../../app/services/qrda/medication_parser"
require_relative "../../../app/services/qrda/status_code_helper"

RSpec.describe MedicationParser do
  let(:xml_file_path) { File.join(File.dirname(__FILE__), "../../fixtures/qrda_sample_medication.xml") }
  let(:xml_content) { File.read(xml_file_path) }
  let(:doc) { Nokogiri::XML(xml_content) }
  let(:ns) { { "hl7" => "urn:hl7-org:v3" } }

  describe ".extract_medication" do
    it "extracts medication information correctly" do
      medication = MedicationParser.extract_medication(doc, ns)

      expect(medication[:medication_id]).to eq("med123")
      expect(medication[:code][:code]).to eq("123456")
      expect(medication[:code][:code_system]).to eq("2.16.840.1.113883.6.88")
      expect(medication[:code][:display]).to eq("Aspirin")
    end

    it "returns nil if no medication is found" do
      doc.xpath("//hl7:entry/hl7:substanceAdministration", ns).remove
      expect(MedicationParser.extract_medication(doc, ns)).to be_nil
    end
  end
end
