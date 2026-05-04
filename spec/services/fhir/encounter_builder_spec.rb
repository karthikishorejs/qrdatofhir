require "rails_helper"
require_relative "../../../app/services/fhir/encounter_builder"

RSpec.describe EncounterBuilder do
  describe ".build_encounter" do
    subject(:encounter) { EncounterBuilder.build_encounter(encounter_data, patient_id) }

    let(:encounter_data) do
      {
        encounter_id: "encounter-1",
        status_code: "finished",
        low_time: "20240101080000",
        high_time: "20240101100000",
        code: { code: "32485007", code_system: "2.16.840.1.113883.6.96", code_system_name: "SNOMEDCT" },
        discharge_disposition: {
          code: "428371000124100",
          code_system: "http://snomed.info/sct",
          display: "Discharge to healthcare facility for hospice care (procedure)"
        }
      }
    end
    let(:patient_id) { "patient-1" }
    let(:encounter_class) { encounter.to_hash["class"] }
    let(:type_coding) { encounter.type.first.coding.first }
    let(:discharge_disposition_coding) { encounter.hospitalization.dischargeDisposition.coding.first }

    it "sets the encounter id" do
      expect(encounter.id).to eq("encounter-1")
    end

    it "sets the encounter status" do
      expect(encounter.status).to eq("finished")
    end

    it "references the patient" do
      expect(encounter.subject.reference).to eq("Patient/patient-1")
    end

    it "sets the period start time" do
      expect(encounter.period.start).to eq("2024-01-01T08:00:00.000+00:00")
    end

    it "sets the period end time" do
      expect(encounter.period.end).to eq("2024-01-01T10:00:00.000+00:00")
    end

    it "applies the qicore encounter profile" do
      expect(encounter.meta.profile.first).to eq(FHIRConstants::QICORE_ENCOUNTER_PROFILE)
    end

    it "sets the encounter class system" do
      expect(encounter_class["system"]).to eq("http://terminology.hl7.org/CodeSystem/v3-ActCode")
    end

    it "sets the encounter class code" do
      expect(encounter_class["code"]).to eq("IMP")
    end

    it "sets the encounter class display" do
      expect(encounter_class["display"]).to eq("inpatient encounter")
    end

    it "sets the type coding system" do
      expect(type_coding.system).to eq(FHIRConstants::SNOMED_SYSTEM)
    end

    it "sets the type coding code" do
      expect(type_coding.code).to eq("32485007")
    end

    it "sets the type coding display" do
      expect(type_coding.display).to eq("SNOMEDCT")
    end

    it "maps the discharge disposition system" do
      expect(discharge_disposition_coding.system).to eq("http://terminology.hl7.org/CodeSystem/discharge-disposition")
    end

    it "maps the discharge disposition code" do
      expect(discharge_disposition_coding.code).to eq("home")
    end

    it "maps the discharge disposition display" do
      expect(discharge_disposition_coding.display).to eq("Home")
    end
  end
end
