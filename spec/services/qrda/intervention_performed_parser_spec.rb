require "nokogiri"
require_relative "../../../app/services/qrda/intervention_performed_parser"

RSpec.describe InterventionPerformedParser do
  let(:ns) { { "hl7" => "urn:hl7-org:v3", "xsi" => "http://www.w3.org/2001/XMLSchema-instance" } }

  let(:xml) do
    <<~XML
      <ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <component>
          <structuredBody>
            <component>
              <section>
                <entry typeCode="DRIV">
                  <act classCode="ACT" moodCode="EVN">
                    <templateId root="2.16.840.1.113883.10.20.24.3.32" extension="2021-08-01"/>
                    <id root="root-ip" extension="50576109"/>
                    <code code="XYZ" codeSystem="2.16.840.1.113883.6.96" displayName="Intervention performed" codeSystemName="SNMCT"/>
                    <statusCode code="completed"/>
                    <effectiveTime>
                      <low value="20251001120000-0400"/>
                    </effectiveTime>
                    <entryRelationship typeCode="REFR">
                      <observation classCode="OBS" moodCode="EVN">
                        <templateId root="2.16.840.1.113883.10.20.24.3.87" extension="2019-12-01"/>
                        <code code="R" codeSystem="2.16.840.1.113883.6.1" displayName="Result" codeSystemName="LOINC"/>
                        <effectiveTime value="20251001120000-0400"/>
                        <value xsi:type="INT" value="2"/>
                      </observation>
                    </entryRelationship>
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

  it "extracts intervention performed and embedded result observation" do
    p = described_class.extract_one(doc, ns)

    expect(p).not_to be_nil
    expect(p[:encounter_extension]).to eq("50576109")
    expect(p[:code][:code]).to eq("XYZ")
    expect(p[:effective_low]).to eq("20251001120000-0400")

    expect(p[:result]).not_to be_nil
    expect(p[:result][:code][:code]).to eq("R")
    expect(p[:result][:value][:value]).to eq("2")
  end
end
