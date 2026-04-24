require "nokogiri"
require "securerandom"
require_relative "../../../app/services/qrda/patient_parser"

RSpec.describe PatientParser, type: :service do
  let(:xml_file_path) { File.join(File.dirname(__FILE__), "../../fixtures/qrda_sample.xml") }
  let(:xml_content) { File.read(xml_file_path) }
  let(:doc) { Nokogiri::XML(xml_content) }
  let(:ns) { { "hl7" => "urn:hl7-org:v3" } }

  describe ".extract_patient" do
    subject(:patient) { PatientParser.extract_patient(doc, ns) }

    it "extracts the patient id" do
      expect(patient[:id]).to eq("12345")
    end

    it "extracts the birth date" do
      expect(patient[:birth_date]).to eq("19910302190000")
    end

    it "extracts the gender" do
      expect(patient[:gender]).to eq("female")
    end

    it "extracts the given name" do
      expect(patient[:name][:given]).to eq("Age17InEDAge18DayOfIPAdmit")
    end

    it "extracts the family name" do
      expect(patient[:name][:family]).to eq("DENOMPass")
    end

    it "extracts the race code" do
      expect(patient[:race][:code]).to eq("1002-5")
    end

    it "extracts the race system" do
      expect(patient[:race][:system]).to eq("2.16.840.1.113883.6.238")
    end

    it "extracts the ethnicity code" do
      expect(patient[:ethnicity][:code]).to eq("2135-2")
    end

    it "extracts the ethnicity system" do
      expect(patient[:ethnicity][:system]).to eq("2.16.840.1.113883.6.238")
    end
  end

  describe ".extract_patient_id" do
    subject(:patient_id) { PatientParser.extract_patient_id(doc, ns) }

    it "extracts the patient id when present" do
      expect(patient_id).to eq("12345")
    end

    context "when no patient id is present" do
      before do
        doc.xpath("//hl7:id", ns).remove
      end

      it "generates a uuid" do
        expect(patient_id).to match(/\A[\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12}\z/)
      end
    end
  end

  describe ".extract_birth_date" do
    it "extracts the birth date" do
      expect(PatientParser.extract_birth_date(doc, ns)).to eq("19910302190000")
    end
  end

  describe ".extract_gender" do
    subject(:gender) { PatientParser.extract_gender(doc, ns) }

    it "extracts the gender" do
      expect(gender).to eq("female")
    end

    context "when gender is missing" do
      before do
        doc.xpath("//hl7:administrativeGenderCode", ns).remove
      end

      it "returns unknown" do
        expect(gender).to eq("unknown")
      end
    end
  end

  describe ".extract_name" do
    subject(:name) { PatientParser.extract_name(doc, ns) }

    it "extracts the given name" do
      expect(name[:given]).to eq("Age17InEDAge18DayOfIPAdmit")
    end

    it "extracts the family name" do
      expect(name[:family]).to eq("DENOMPass")
    end
  end

  describe ".extract_race_and_ethnicity" do
    subject(:result) { PatientParser.extract_race_and_ethnicity(doc, ns) }

    it "extracts the race code" do
      expect(result[:race][:code]).to eq("1002-5")
    end

    it "extracts the race system" do
      expect(result[:race][:system]).to eq("2.16.840.1.113883.6.238")
    end

    it "extracts the ethnicity code" do
      expect(result[:ethnicity][:code]).to eq("2135-2")
    end

    it "extracts the ethnicity system" do
      expect(result[:ethnicity][:system]).to eq("2.16.840.1.113883.6.238")
    end
  end
end
