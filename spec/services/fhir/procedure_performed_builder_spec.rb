require_relative "../../../app/services/fhir/procedure_performed_builder"

RSpec.describe ProcedurePerformedBuilder do
  it "builds a Procedure and includes ordinality extension when present" do
    proc =
      described_class.build_procedure(
        {
          performed_id: "pp1",
          negation_ind: false,
          status_code: "completed",
          effective_low: "20251001120000-0400",
          effective_high: nil,
          code: { code: "PROC1", code_system: "2.16.840.1.113883.6.96", display: "A procedure" },
          ordinality_rank: 3
        },
        "pat1",
        encounter_id: "enc1"
      )

    expect(proc.resourceType).to eq("Procedure")
    expect(proc.id).to eq("pp1")
    expect(proc.status).to eq("completed")
    expect(proc.encounter.reference).to eq("Encounter/enc1")
    expect(proc.extension).not_to be_nil
    expect(proc.extension.first.valueInteger).to eq(3)
  end
end
