require "rails_helper"
require_relative "../../../app/services/fhir/fhir_bundle_builder"

RSpec.describe FhirBundleBuilder do
  describe ".build_patient" do
    let(:patient_data) { { id: "patient-1", gender: "female", birth_date: "19800101", name: { given: "Jane", family: "Doe" } } }

    it "delegates to PatientBuilder.build_patient" do
      expect(PatientBuilder).to receive(:build_patient).with(patient_data)
      FhirBundleBuilder.build_patient(patient_data)
    end
  end

  describe ".build_encounter" do
    let(:encounter_data) do
      {
        encounter_id: "encounter-1",
        status_code: "finished",
        low_time: "20240101080000",
        high_time: "20240101100000",
        code: { code: "32485007", code_system: "2.16.840.1.113883.6.96", code_system_name: "SNOMEDCT" }
      }
    end
    let(:patient_id) { "patient-1" }

    it "delegates to EncounterBuilder.build_encounter" do
      expect(EncounterBuilder).to receive(:build_encounter).with(encounter_data, patient_id)
      FhirBundleBuilder.build_encounter(encounter_data, patient_id)
    end
  end

  describe ".build_medication" do
    let(:medication_data) { { low_time: "20240101080000", high_time: "20240101100000" } }
    let(:patient_id) { "patient-1" }

    it "delegates to MedicationBuilder.build_medication" do
      expect(MedicationBuilder).to receive(:build_medication).with(medication_data.merge(encounter_id: nil), patient_id)
      FhirBundleBuilder.build_medication(medication_data, patient_id)
    end

    it "routes order medications to MedicationRequestBuilder" do
      data = medication_data.merge(kind: "order")
      expect(MedicationRequestBuilder).to receive(:build_request).with(data, patient_id, encounter_id: nil)
      FhirBundleBuilder.build_medication(data, patient_id)
    end

    it "routes active medications to MedicationStatementBuilder" do
      data = medication_data.merge(kind: "active")
      expect(MedicationStatementBuilder).to receive(:build_statement).with(data, patient_id, encounter_id: nil)
      FhirBundleBuilder.build_medication(data, patient_id)
    end

    it "routes discharge medications to MedicationRequestBuilder with category=discharge" do
      data = medication_data.merge(kind: "discharge")
      expect(MedicationRequestBuilder).to receive(:build_request).with(
        data.merge(category: "discharge"),
        patient_id,
        encounter_id: nil
      )
      FhirBundleBuilder.build_medication(data, patient_id)
    end
  end
end
