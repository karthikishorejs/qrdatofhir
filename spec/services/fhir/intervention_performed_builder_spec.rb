require_relative "../../../app/services/fhir/intervention_performed_builder"

RSpec.describe InterventionPerformedBuilder do
  it "builds a Procedure with completed status and encounter linkage" do
    proc =
      described_class.build_procedure(
        {
          performed_id: "p1",
          negation_ind: false,
          status_code: "completed",
          effective_low: "20251001120000-0400",
          effective_high: nil,
          code: { code: "XYZ", code_system: "2.16.840.1.113883.6.96", display: "Intervention performed" }
        },
        "pat1",
        encounter_id: "enc1"
      )

    expect(proc.resourceType).to eq("Procedure")
    expect(proc.id).to eq("p1")
    expect(proc.status).to eq("completed")
    expect(proc.subject.reference).to eq("Patient/pat1")
    expect(proc.encounter.reference).to eq("Encounter/enc1")
    expect(proc.code.coding.first.code).to eq("XYZ")
    expect(proc.performedDateTime).not_to be_nil
  end
end
