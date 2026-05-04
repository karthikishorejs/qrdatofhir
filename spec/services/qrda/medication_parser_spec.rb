require "nokogiri"
require_relative "../../../app/services/qrda/medication_parser"
require_relative "../../../app/services/qrda/status_code_helper"

RSpec.describe MedicationParser do
  let(:xml_file_path) { File.join(File.dirname(__FILE__), "../../fixtures/qrda_sample_medication.xml") }
  let(:xml_content) { File.read(xml_file_path) }
  let(:doc) { Nokogiri::XML(xml_content) }
  let(:ns) { { "hl7" => "urn:hl7-org:v3" } }

  describe ".extract_medication" do
    it "extracts medication information correctly" do
      medication = MedicationParser.extract_medication(doc, ns)

      # Medication ids are now suffixed to ensure uniqueness per event
      expect(medication[:medication_id]).to start_with("med123")
      expect(medication[:code][:code]).to eq("123456")
      expect(medication[:code][:code_system]).to eq("2.16.840.1.113883.6.88")
      expect(medication[:code][:display]).to eq("Aspirin")
    end

    it "returns nil if no medication is found" do
      doc.xpath("//hl7:entry/hl7:substanceAdministration", ns).remove
      expect(MedicationParser.extract_medication(doc, ns)).to be_nil
    end
  end

  describe ".extract_medications" do
    it "keeps same-time discharge medications as distinct resources" do
      xml = <<~XML
        <ClinicalDocument xmlns="urn:hl7-org:v3">
          <component>
            <structuredBody>
              <component>
                <section>
                  <entry>
                    <act classCode="ACT" moodCode="RQO">
                      <templateId root="2.16.840.1.113883.10.20.24.3.105"/>
                      <entryRelationship>
                        <substanceAdministration classCode="SBADM" moodCode="EVN">
                          <id root="db1687b8-e8e1-47a9-b5cd-6ef7ed0c36fd" extension="104643180"/>
                          <statusCode code="active"/>
                          <effectiveTime value="20250624141300-0600"/>
                          <consumable>
                            <manufacturedProduct>
                              <manufacturedMaterial>
                                <code code="835603" codeSystem="2.16.840.1.113883.6.88" displayName="tramadol hydrochloride 50 MG Oral Tablet"/>
                              </manufacturedMaterial>
                            </manufacturedProduct>
                          </consumable>
                        </substanceAdministration>
                      </entryRelationship>
                    </act>
                  </entry>
                  <entry>
                    <act classCode="ACT" moodCode="RQO">
                      <templateId root="2.16.840.1.113883.10.20.24.3.105"/>
                      <entryRelationship>
                        <substanceAdministration classCode="SBADM" moodCode="EVN">
                          <id root="b5525751-250a-43ee-b19f-9d7d4cf7e05d" extension="104643180"/>
                          <statusCode code="active"/>
                          <effectiveTime value="20250624141300-0600"/>
                          <consumable>
                            <manufacturedProduct>
                              <manufacturedMaterial>
                                <code code="1049621" codeSystem="2.16.840.1.113883.6.88" displayName="oxycodone hydrochloride 5 MG Oral Tablet"/>
                              </manufacturedMaterial>
                            </manufacturedProduct>
                          </consumable>
                        </substanceAdministration>
                      </entryRelationship>
                    </act>
                  </entry>
                </section>
              </component>
            </structuredBody>
          </component>
        </ClinicalDocument>
      XML

      meds = MedicationParser.extract_medications(Nokogiri::XML(xml), ns)

      expect(meds.map { |m| m[:code][:code] }).to contain_exactly("835603", "1049621")
      expect(meds.map { |m| m[:medication_id] }.uniq.size).to eq(2)
      expect(meds.map { |m| m[:medication_id] }).to all(start_with("104643180-"))
    end
  end
end
