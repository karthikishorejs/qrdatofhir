require "nokogiri"
require_relative "../../../app/services/qrda/encounter_parser"

RSpec.describe EncounterParser do
  let(:xml_file_path) { File.join(File.dirname(__FILE__), "../../fixtures/qrda_sample_encounter.xml") }
  let(:xml_content) { File.read(xml_file_path) }
  let(:doc) { Nokogiri::XML(xml_content) }
  let(:ns) { { "hl7" => "urn:hl7-org:v3", "sdtc" => "urn:hl7-org:sdtc" } }

  describe ".extract_encounter" do
    it "extracts encounter information correctly" do
      encounter = EncounterParser.extract_encounter(doc, ns)

      expect(encounter[:encounter_id]).to eq("encounter123")
      expect(encounter[:low_time]).to eq("20250101")
      expect(encounter[:high_time]).to eq("20250102")
      expect(encounter[:status_code]).to eq("finished")
      expect(encounter[:code][:code]).to eq("99213")
      expect(encounter[:code][:code_system]).to eq("2.16.840.1.113883.6.12")
      expect(encounter[:code][:code_system_name]).to eq("CPT")
      expect(encounter[:hospitalization][:discharge_disposition][:code]).to eq("428371000124100")
      expect(encounter[:hospitalization][:discharge_disposition][:code_system]).to eq("2.16.840.1.113883.6.96")
      expect(encounter[:hospitalization][:discharge_disposition][:code_system_name]).to eq("SNOMEDCT")
    end

    it "returns nil if no encounter is found" do
      doc.xpath("//hl7:entry/hl7:encounter", ns).remove
      expect(EncounterParser.extract_encounter(doc, ns)).to be_nil
    end
  end

  describe ".extract_encounter_status_code" do
    it "maps 'completed' to 'finished'" do
      expect(EncounterParser.extract_encounter_status_code("completed")).to eq("finished")
    end

    it "maps 'in-progress' to 'in-progress'" do
      expect(EncounterParser.extract_encounter_status_code("in-progress")).to eq("in-progress")
    end

    it "returns 'unknown' for unrecognized status codes" do
      expect(EncounterParser.extract_encounter_status_code("unknown-status")).to eq("unknown")
    end

    it "returns 'unknown' if status code is nil" do
      expect(EncounterParser.extract_encounter_status_code(nil)).to eq("unknown")
    end
  end
end
