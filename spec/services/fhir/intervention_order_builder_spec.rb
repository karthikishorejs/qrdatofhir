require_relative "../../../app/services/fhir/intervention_order_builder"

RSpec.describe InterventionOrderBuilder do
  it "builds a ServiceRequest with intent order and encounter linkage" do
    sr =
      described_class.build_service_request(
        {
          order_id: "o1",
          negation_ind: false,
          status_code: "active",
          effective_low: "20251001120000-0400",
          effective_high: nil,
          code: { code: "ABC", code_system: "2.16.840.1.113883.6.96", display: "Some Intervention" }
        },
        "pat1",
        encounter_id: "enc1"
      )

    expect(sr.resourceType).to eq("ServiceRequest")
    expect(sr.id).to eq("o1")
    expect(sr.intent).to eq("order")
    expect(sr.status).to eq("active")
    expect(sr.subject.reference).to eq("Patient/pat1")
    expect(sr.encounter.reference).to eq("Encounter/enc1")
    expect(sr.code.coding.first.code).to eq("ABC")
    expect(sr.authoredOn).to eq("2025-10-01T16:00:00.000Z")
    expect(sr.occurrenceDateTime).not_to be_nil
  end
end
