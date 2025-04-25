require "securerandom"
require_relative "./status_code_helper"

# EncounterParser is responsible for extracting encounter information from a QRDA document.
class EncounterParser
  extend StatusCodeHelper

  def self.extract_encounter(doc, ns)
    encounter_node = doc.at_xpath("//hl7:entry/hl7:encounter", ns)
    return nil unless encounter_node

    {
      encounter_id: encounter_node.at_xpath("hl7:id", ns)&.[]("extension"),
      low_time: encounter_node.at_xpath("hl7:effectiveTime/hl7:low", ns)&.[]("value"),
      high_time: encounter_node.at_xpath("hl7:effectiveTime/hl7:high", ns)&.[]("value"),
      status_code: extract_status_code(encounter_node.at_xpath("hl7:statusCode", ns)&.[]("code")),
      code: {
        code: encounter_node.at_xpath("hl7:code", ns)&.[]("code"),
        code_system: encounter_node.at_xpath("hl7:code", ns)&.[]("codeSystem"),
        code_system_name: encounter_node.at_xpath("hl7:code", ns)&.[]("codeSystemName")
      }
    }
  end

  def self.extract_encounter_status_code(status_code)
    return "unknown" unless status_code
    # Normalize the status code to lowercase for consistent comparison
    status_code = status_code.downcase

    # Map the status code to a more descriptive term
    case status_code
    when "completed"
      "finished"
    when "in-progress"
      "in-progress"
    else
      "unknown"
    end
  end
end
