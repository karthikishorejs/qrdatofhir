require "nokogiri"
require_relative "../../../app/services/qrda/assessment_parser"

RSpec.describe AssessmentParser do
  let(:ns) { { "hl7" => "urn:hl7-org:v3", "xsi" => "http://www.w3.org/2001/XMLSchema-instance" } }

  let(:xml) do
    <<~XML
      <ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <component>
          <structuredBody>
            <component>
              <section>
                <entry typeCode="DRIV">
                  <observation classCode="OBS" moodCode="EVN">
                    <templateId root="2.16.840.1.113883.10.20.24.3.144" extension="2021-08-01"/>
                    <id root="root-1" extension="50576109"/>
                    <code code="1234" codeSystem="2.16.840.1.113883.6.1" displayName="Some Assessment" codeSystemName="LOINC"/>
                    <statusCode code="completed"/>
                    <effectiveTime value="20251002135100-0400"/>
                    <value xsi:type="CD" code="A" codeSystem="2.16.840.1.113883.6.96" displayName="Alpha"/>
                  </observation>
                </entry>
              </section>
            </component>
          </structuredBody>
        </component>
      </ClinicalDocument>
    XML
  end

  let(:doc) { Nokogiri::XML(xml) }

  it "extracts assessments by templateId and returns expected fields" do
    a = described_class.extract_assessment(doc, ns)

    expect(a).not_to be_nil
    expect(a[:encounter_extension]).to eq("50576109")
    expect(a[:code][:code]).to eq("1234")
    expect(a[:code][:code_system]).to eq("2.16.840.1.113883.6.1")
    expect(a[:status_code]).to eq("completed")
    expect(a[:effective_low]).to eq("20251002135100-0400")
    expect(a[:value][:code]).to eq("A")
  end

  it "returns empty array when none present" do
    doc2 = Nokogiri::XML("<ClinicalDocument xmlns='urn:hl7-org:v3'/>")
    expect(described_class.extract_assessments(doc2, ns)).to eq([])
  end
end
