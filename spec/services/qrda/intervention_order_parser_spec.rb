require "nokogiri"
require_relative "../../../app/services/qrda/intervention_order_parser"

RSpec.describe InterventionOrderParser do
  let(:ns) { { "hl7" => "urn:hl7-org:v3" } }

  let(:xml) do
    <<~XML
      <ClinicalDocument xmlns="urn:hl7-org:v3">
        <component>
          <structuredBody>
            <component>
              <section>
                <entry typeCode="DRIV">
                  <act classCode="ACT" moodCode="RQO">
                    <templateId root="2.16.840.1.113883.10.20.24.3.31" extension="2021-08-01"/>
                    <id root="root-io" extension="50576109"/>
                    <code code="ABC" codeSystem="2.16.840.1.113883.6.96" displayName="Some Intervention" codeSystemName="SNMCT"/>
                    <statusCode code="active"/>
                    <effectiveTime value="20251001120000-0400"/>
                  </act>
                </entry>
              </section>
            </component>
          </structuredBody>
        </component>
      </ClinicalDocument>
    XML
  end

  let(:doc) { Nokogiri::XML(xml) }

  it "extracts intervention orders" do
    o = described_class.extract_order(doc, ns)

    expect(o).not_to be_nil
    expect(o[:encounter_extension]).to eq("50576109")
    expect(o[:code][:code]).to eq("ABC")
    expect(o[:status_code]).to eq("active")
    expect(o[:effective_low]).to eq("20251001120000-0400")
  end
end
