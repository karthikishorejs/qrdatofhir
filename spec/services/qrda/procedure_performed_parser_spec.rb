require "nokogiri"
require_relative "../../../app/services/qrda/procedure_performed_parser"

RSpec.describe ProcedurePerformedParser do
  let(:ns) { { "hl7" => "urn:hl7-org:v3", "xsi" => "http://www.w3.org/2001/XMLSchema-instance" } }

  let(:xml) do
    <<~XML
      <ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <component>
          <structuredBody>
            <component>
              <section>
                <entry typeCode="DRIV">
                  <procedure classCode="PROC" moodCode="EVN">
                    <templateId root="2.16.840.1.113883.10.20.24.3.64" extension="2021-08-01"/>
                    <id root="root-pp" extension="50576109"/>
                    <code code="PROC1" codeSystem="2.16.840.1.113883.6.96" displayName="A procedure" codeSystemName="SNMCT"/>
                    <statusCode code="completed"/>
                    <effectiveTime>
                      <low value="20251001120000-0400"/>
                    </effectiveTime>
                    <entryRelationship typeCode="REFR">
                      <observation classCode="OBS" moodCode="EVN">
                        <templateId root="2.16.840.1.113883.10.20.24.3.166" extension="2019-12-01"/>
                        <value xsi:type="INT" value="3"/>
                      </observation>
                    </entryRelationship>
                  </procedure>
                </entry>
              </section>
            </component>
          </structuredBody>
        </component>
      </ClinicalDocument>
    XML
  end

  let(:doc) { Nokogiri::XML(xml) }

  it "extracts procedure performed and ordinality rank" do
    p = described_class.extract_performed(doc, ns)

    expect(p).not_to be_nil
    expect(p[:encounter_extension]).to eq("50576109")
    expect(p[:code][:code]).to eq("PROC1")
    expect(p[:effective_low]).to eq("20251001120000-0400")
    expect(p[:ordinality_rank]).to eq(3)
  end
end
