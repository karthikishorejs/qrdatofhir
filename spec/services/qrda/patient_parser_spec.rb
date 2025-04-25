require "nokogiri"
require "securerandom"
require_relative "../../../app/services/qrda/patient_parser"

RSpec.describe PatientParser, type: :service do
  let(:xml_file_path) { File.join(File.dirname(__FILE__), "../../fixtures/qrda_sample.xml") }
  let(:xml_content) { File.read(xml_file_path) }
  let(:doc) { Nokogiri::XML(xml_content) }
  let(:ns) { { "hl7" => "urn:hl7-org:v3" } }

  describe ".extract_patient" do
    it "extracts all patient information correctly" do
      patient = PatientParser.extract_patient(doc, ns)

      expect(patient[:id]).to eq("12345")
      expect(patient[:birth_date]).to eq("19910302190000")
      expect(patient[:gender]).to eq("f")
      expect(patient[:name][:given]).to eq("Age17InEDAge18DayOfIPAdmit")
      expect(patient[:name][:family]).to eq("DENOMPass")
      expect(patient[:race][:code]).to eq("1002-5")
      expect(patient[:race][:system]).to eq("2.16.840.1.113883.6.238")
      expect(patient[:ethnicity][:code]).to eq("2135-2")
      expect(patient[:ethnicity][:system]).to eq("2.16.840.1.113883.6.238")
    end
  end

  describe ".extract_patient_id" do
    it "extracts the patient ID if present" do
      expect(PatientParser.extract_patient_id(doc, ns)).to eq("12345")
    end

    it "generates a UUID if no patient ID is present" do
      doc.xpath("//hl7:id", ns).remove
      expect(PatientParser.extract_patient_id(doc, ns)).to match(/\A[\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12}\z/)
    end
  end

  describe ".extract_birth_date" do
    it "extracts the birth date" do
      expect(PatientParser.extract_birth_date(doc, ns)).to eq("19910302190000")
    end
  end

  describe ".extract_gender" do
    it "extracts the gender" do
      expect(PatientParser.extract_gender(doc, ns)).to eq("f")
    end

    it "returns 'unknown' if gender is not present" do
      doc.xpath("//hl7:administrativeGenderCode", ns).remove
      expect(PatientParser.extract_gender(doc, ns)).to eq("unknown")
    end
  end

  describe ".extract_name" do
    it "extracts the patient's name" do
      name = PatientParser.extract_name(doc, ns)
      expect(name[:given]).to eq("Age17InEDAge18DayOfIPAdmit")
      expect(name[:family]).to eq("DENOMPass")
    end
  end

  describe ".extract_race_and_ethnicity" do
    it "extracts race and ethnicity correctly" do
      result = PatientParser.extract_race_and_ethnicity(doc, ns)

      expect(result[:race][:code]).to eq("1002-5")
      expect(result[:race][:system]).to eq("2.16.840.1.113883.6.238")

      expect(result[:ethnicity][:code]).to eq("2135-2")
      expect(result[:ethnicity][:system]).to eq("2.16.840.1.113883.6.238")
    end
  end
end
