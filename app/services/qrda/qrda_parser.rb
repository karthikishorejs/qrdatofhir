require "nokogiri"
require "securerandom"

class QrdaParser
  attr_reader :doc, :ns

  def initialize(file)
    @doc = Nokogiri::XML(file)
    @ns = { "hl7" => "urn:hl7-org:v3" }
  end

  def extract_patient
    {
      id: extract_patient_id,
      birth_date: extract_birth_date,
      gender: extract_gender,
      race: extract_race_and_ethnicity[:race],
      name: extract_name,
      ethnicity: extract_race_and_ethnicity[:ethnicity]
    }
  end

  def extract_encounter
    encounter_node = doc.at_xpath("//hl7:entry/hl7:encounter", ns)
    return nil unless encounter_node

    {
      encounter_id: encounter_node.at_xpath("hl7:id", ns)&.[]("extension"),
      low_time: encounter_node.at_xpath("hl7:effectiveTime/hl7:low", ns)&.[]("value"),
      high_time: encounter_node.at_xpath("hl7:effectiveTime/hl7:high", ns)&.[]("value"),
      status_code: extract_encounter_status_code(encounter_node.at_xpath("hl7:statusCode", ns)&.[]("code")),
      code: {
        code: encounter_node.at_xpath("hl7:code", ns)&.[]("code"),
        code_system: encounter_node.at_xpath("hl7:code", ns)&.[]("codeSystem"),
        code_system_name: encounter_node.at_xpath("hl7:code", ns)&.[]("codeSystemName")
      }
    }
  end

  def extract_medication
    medication_node = doc.at_xpath("//hl7:entry/hl7:substanceAdministration", ns)
    return nil unless medication_node
    {
      medication_id: medication_node.at_xpath("hl7:consumable/hl7:manufacturedProduct/hl7:code", ns)&.[]("code"),
      low_time: medication_node.at_xpath("hl7:effectiveTime/hl7:low", ns)&.[]("value"),
      high_time: medication_node.at_xpath("hl7:effectiveTime/hl7:high", ns)&.[]("value"),
      status_code: extract_encounter_status_code(medication_node.at_xpath("hl7:statusCode", ns)&.[]("code")),
      code: {
        code: medication_node.at_xpath("hl7:code", ns)&.[]("code"),
        code_system: medication_node.at_xpath("hl7:code", ns)&.[]("codeSystem"),
        code_system_name: medication_node.at_xpath("hl7:code", ns)&.[]("codeSystemName")
      }
    }
  end

  private

  def extract_patient_id
    doc.at_xpath("//hl7:patientRole/hl7:id", ns)&.[]("extension") || SecureRandom.uuid
  end

  def extract_birth_date
    doc.at_xpath("//hl7:birthTime", ns)&.[]("value")
  end

  def extract_gender
    doc.at_xpath("//hl7:administrativeGenderCode", ns)&.[]("code")&.downcase || "unknown"
  end

  def extract_name
    {
      given: doc.at_xpath("//hl7:patient/hl7:name/hl7:given", ns)&.text,
      family: doc.at_xpath("//hl7:patient/hl7:name/hl7:family", ns)&.text
    }
  end

  def extract_race_and_ethnicity
    {
      race: extract_code_details("//hl7:raceCode"),
      ethnicity: extract_code_details("//hl7:ethnicGroupCode")
    }
  end

  def extract_code_details(xpath)
    node = doc.at_xpath(xpath, ns)
    {
      code: node&.[]("code"),
      display: node&.[]("display"),
      system: node&.[]("codeSystem")
    }
  end

  def extract_encounter_status_code(status_code)
    if status_code == "completed"
      "finished"
    elsif status_code == "in-progress"
      "in-progress"
    else
      "unknown"
    end
  end
end
