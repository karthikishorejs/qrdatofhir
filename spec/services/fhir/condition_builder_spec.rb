require "rails_helper"
require_relative "../../../app/services/fhir/condition_builder"

RSpec.describe ConditionBuilder do
  describe ".build_condition" do
    it "uses diagnosis_id and links encounter when provided" do
      condition =
        described_class.build_condition(
          {
            diagnosis_id: "diag_1",
            diagnosis: {
              code: "E11.9",
              code_system: "2.16.840.1.113883.6.90",
              display: "Type 2 diabetes mellitus without complications"
            }
          },
          "patient-1",
          encounter_id: "enc_1"
        )

      expect(condition.id).to eq("diag-1")
      expect(condition.subject.reference).to eq("Patient/patient-1")
      expect(condition.encounter.reference).to eq("Encounter/enc-1")
      expect(condition.code.coding.first.system).to eq("http://hl7.org/fhir/sid/icd-10-cm")
      expect(condition.code.coding.first.code).to eq("E11.9")
    end
  end
end
