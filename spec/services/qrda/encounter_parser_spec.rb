require "nokogiri"
require_relative "../../../app/services/qrda/encounter_parser"

RSpec.describe EncounterParser do
  let(:xml_file_path) { File.join(File.dirname(__FILE__), "../../fixtures/qrda_sample_encounter.xml") }
  let(:xml_content) { File.read(xml_file_path) }
  let(:doc) { Nokogiri::XML(xml_content) }
  let(:ns) { { "hl7" => "urn:hl7-org:v3", "sdtc" => "urn:hl7-org:sdtc" } }

  describe ".extract_encounter" do
    subject(:encounter) { EncounterParser.extract_encounter(doc, ns) }

    it "extracts the encounter id" do
      expect(encounter[:encounter_id]).to eq("encounter123")
    end

    it "extracts the low time" do
      expect(encounter[:low_time]).to eq("20250101")
    end

    it "extracts the high time" do
      expect(encounter[:high_time]).to eq("20250102")
    end

    it "extracts the status code" do
      expect(encounter[:status_code]).to eq("finished")
    end

    it "extracts the encounter code" do
      expect(encounter[:code][:code]).to eq("99213")
    end

    it "extracts the encounter code system" do
      expect(encounter[:code][:code_system]).to eq("2.16.840.1.113883.6.12")
    end

    it "extracts the encounter code system name" do
      expect(encounter[:code][:code_system_name]).to eq("CPT")
    end

    it "extracts the discharge disposition code" do
      expect(encounter[:hospitalization][:discharge_disposition][:code]).to eq("428371000124100")
    end

    it "extracts the discharge disposition code system" do
      expect(encounter[:hospitalization][:discharge_disposition][:code_system]).to eq("2.16.840.1.113883.6.96")
    end

    it "extracts the discharge disposition code system name" do
      expect(encounter[:hospitalization][:discharge_disposition][:code_system_name]).to eq("SNOMEDCT")
    end

    context "when no encounter is present" do
      before do
        doc.xpath("//hl7:entry/hl7:encounter", ns).remove
      end

      it "returns nil" do
        expect(encounter).to be_nil
      end
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
