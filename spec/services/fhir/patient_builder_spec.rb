require "rails_helper"
require_relative "../../../app/services/fhir/patient_builder"

RSpec.describe PatientBuilder do
  describe ".build_patient" do
    subject(:patient) { PatientBuilder.build_patient(patient_data) }

    let(:patient_data) do
      {
        id: "patient-1",
        gender: "female",
        birth_date: "19800101",
        name: { given: "Jane", family: "Doe" },
        race: { code: "2106-3", display: "White" },
        ethnicity: { code: "2186-5", display: "Not Hispanic or Latino" }
      }
    end
    let(:race_extension) { patient.extension.find { |ext| ext.url == FHIRConstants::US_CORE_RACE_URL } }
    let(:ethnicity_extension) { patient.extension.find { |ext| ext.url == FHIRConstants::US_CORE_ETHNICITY_URL } }

    it "sets the patient id" do
      expect(patient.id).to eq("patient-1")
    end

    it "sets the patient gender" do
      expect(patient.gender).to eq("female")
    end

    it "formats the birth date" do
      expect(patient.birthDate).to eq("1980-01-01")
    end

    it "sets the given name" do
      expect(patient.name.first.given.first).to eq("Jane")
    end

    it "sets the family name" do
      expect(patient.name.first.family).to eq("Doe")
    end

    it "applies the qicore patient profile" do
      expect(patient.meta.profile.first).to eq(FHIRConstants::QICORE_PATIENT_PROFILE)
    end

    it "sets the race code" do
      expect(race_extension.extension.first.valueCoding.code).to eq("2106-3")
    end

    it "sets the race display" do
      expect(race_extension.extension.first.valueCoding.display).to eq("White")
    end

    it "sets the ethnicity code" do
      expect(ethnicity_extension.extension.first.valueCoding.code).to eq("2186-5")
    end

    it "sets the ethnicity display" do
      expect(ethnicity_extension.extension.first.valueCoding.display).to eq("Not Hispanic or Latino")
    end
  end
end
