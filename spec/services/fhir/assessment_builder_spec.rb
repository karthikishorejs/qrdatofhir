require_relative "../../../app/services/fhir/assessment_builder"

RSpec.describe AssessmentBuilder do
  it "builds an Observation with code/effective/value and encounter reference" do
    obs =
      described_class.build_observation(
        {
          assessment_id: "a1",
          negation_ind: false,
          status_code: "completed",
          effective_low: "20251002135100-0400",
          effective_high: nil,
          code: { code: "1234", code_system: "2.16.840.1.113883.6.1", display: "Some Assessment" },
          value: { code: "A", code_system: "2.16.840.1.113883.6.96", display: "Alpha" }
        },
        "pat1",
        encounter_id: "enc1"
      )

    expect(obs.resourceType).to eq("Observation")
    expect(obs.id).to eq("a1")
    expect(obs.status).to eq("final")
    expect(obs.subject.reference).to eq("Patient/pat1")
    expect(obs.encounter.reference).to eq("Encounter/enc1")
    expect(obs.code.coding.first.code).to eq("1234")
    expect(obs.valueCodeableConcept.coding.first.code).to eq("A")
    expect(obs.effectiveDateTime).not_to be_nil
  end
end
