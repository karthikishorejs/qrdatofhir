require "rails_helper"
require_relative "../../../app/services/fhir/medication_builder"

RSpec.describe MedicationBuilder do
  describe ".build_medication" do
    let(:medication_data) do
      {
        low_time: "20240101080000",
        high_time: "20240101100000"
      }
    end
    let(:patient_id) { "patient-1" }

    it "builds a valid FHIR MedicationAdministration resource" do
      medication = MedicationBuilder.build_medication(medication_data, patient_id)

      expect(medication.id).not_to be_nil
      expect(medication.status).to eq("completed")
      expect(medication.subject.reference).to eq("Patient/patient-1")
      expect(medication.effectivePeriod.start).to eq("2024-01-01T08:00:00.000+00:00")
      expect(medication.effectivePeriod.end).to eq("2024-01-01T10:00:00.000+00:00")
      expect(medication.meta.profile.first).to eq(FHIRConstants::QICORE_MEDICATION_PROFILE)

      coding = medication.medicationCodeableConcept.coding.first
      expect(coding.system).to eq(FHIRConstants::RXNORM_SYSTEM)
      expect(coding.code).to eq(FHIRConstants::DEFAULT_MEDICATION_CODE)
    end
  end
end
