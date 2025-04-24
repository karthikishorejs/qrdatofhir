require "rails_helper"
require_relative "../../../app/services/fhir/patient_builder"

RSpec.describe PatientBuilder do
  describe ".build_patient" do
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

    it "builds a valid FHIR Patient resource" do
      patient = PatientBuilder.build_patient(patient_data)

      expect(patient.id).to eq("patient-1")
      expect(patient.gender).to eq("female")
      expect(patient.birthDate).to eq("1980-01-01")
      expect(patient.name.first.given.first).to eq("Jane")
      expect(patient.name.first.family).to eq("Doe")
      expect(patient.meta.profile.first).to eq(FHIRConstants::QICORE_PATIENT_PROFILE)

      race_extension = patient.extension.find { |ext| ext.url == FHIRConstants::US_CORE_RACE_URL }
      expect(race_extension.extension.first.valueCoding.code).to eq("2106-3")
      expect(race_extension.extension.first.valueCoding.display).to eq("White")

      ethnicity_extension = patient.extension.find { |ext| ext.url == FHIRConstants::US_CORE_ETHNICITY_URL }
      expect(ethnicity_extension.extension.first.valueCoding.code).to eq("2186-5")
      expect(ethnicity_extension.extension.first.valueCoding.display).to eq("Not Hispanic or Latino")
    end
  end
end
