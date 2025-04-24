require "rails_helper"
require_relative "../../../app/services/fhir/encounter_builder"

RSpec.describe EncounterBuilder do
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

    it "builds a valid FHIR Encounter resource" do
      encounter = EncounterBuilder.build_encounter(encounter_data, patient_id)

      expect(encounter.id).to eq("encounter-1")
      expect(encounter.status).to eq("finished")
      expect(encounter.subject.reference).to eq("Patient/patient-1")
      expect(encounter.period.start).to eq("2024-01-01T08:00:00.000+00:00")
      expect(encounter.period.end).to eq("2024-01-01T10:00:00.000+00:00")
      expect(encounter.meta.profile.first).to eq(FHIRConstants::QICORE_ENCOUNTER_PROFILE)

      encounter_class = encounter.to_hash['class']
      expect(encounter_class['system']).to eq("http://terminology.hl7.org/CodeSystem/v3-ActCode")
      expect(encounter_class['code']).to eq("IMP")
      expect(encounter_class['display']).to eq("inpatient encounter")

      type_coding = encounter.type.first.coding.first
      expect(type_coding.system).to eq(FHIRConstants::SNOMED_SYSTEM)
      expect(type_coding.code).to eq("32485007")
      expect(type_coding.display).to eq("SNOMEDCT")
    end
  end
end
