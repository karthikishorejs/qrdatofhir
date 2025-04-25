require "securerandom"
require_relative "./status_code_helper"

# MedicationParser is responsible for extracting medication information from a QRDA document.
class MedicationParser
  extend StatusCodeHelper

  def self.extract_medication(doc, ns)
    medication_node = doc.at_xpath("//hl7:entry/hl7:substanceAdministration", ns)
    return nil unless medication_node

    {
    medication_id: medication_node.at_xpath("hl7:id", ns)&.[]("extension"),
    low_time: medication_node.at_xpath("hl7:effectiveTime/hl7:low", ns)&.[]("value"),
    high_time: medication_node.at_xpath("hl7:effectiveTime/hl7:high", ns)&.[]("value"),
    status_code: extract_status_code(medication_node.at_xpath("hl7:statusCode", ns)&.[]("code")),
    code: {
        code: medication_node.at_xpath("hl7:consumable/hl7:manufacturedProduct/hl7:manufacturedMaterial/hl7:code", ns)&.[]("code"),
        code_system: medication_node.at_xpath("hl7:consumable/hl7:manufacturedProduct/hl7:manufacturedMaterial/hl7:code", ns)&.[]("codeSystem"),
        code_system_name: medication_node.at_xpath("hl7:consumable/hl7:manufacturedProduct/hl7:manufacturedMaterial/hl7:code", ns)&.[]("codeSystemName"),
        display: medication_node.at_xpath("hl7:consumable/hl7:manufacturedProduct/hl7:manufacturedMaterial/hl7:code", ns)&.[]("displayName")
      }
    }
  end
end
