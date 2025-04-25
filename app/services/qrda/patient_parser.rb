require "securerandom"

# PatientParser is responsible for extracting patient information from a QRDA document.
class PatientParser
  def self.extract_patient(doc, ns)
    {
      id: extract_patient_id(doc, ns),
      birth_date: extract_birth_date(doc, ns),
      gender: extract_gender(doc, ns),
      race: extract_race_and_ethnicity(doc, ns)[:race],
      name: extract_name(doc, ns),
      ethnicity: extract_race_and_ethnicity(doc, ns)[:ethnicity]
    }
  end

  def self.extract_patient_id(doc, ns)
    doc.at_xpath("//hl7:patientRole/hl7:id", ns)&.[]("extension") || SecureRandom.uuid
  end

  def self.extract_birth_date(doc, ns)
    doc.at_xpath("//hl7:birthTime", ns)&.[]("value")
  end

  def self.extract_gender(doc, ns)
    doc.at_xpath("//hl7:administrativeGenderCode", ns)&.[]("code")&.downcase || "unknown"
  end

  def self.extract_name(doc, ns)
    {
      given: doc.at_xpath("//hl7:patient/hl7:name/hl7:given", ns)&.text,
      family: doc.at_xpath("//hl7:patient/hl7:name/hl7:family", ns)&.text
    }
  end

  def self.extract_race_and_ethnicity(doc, ns)
    {
      race: extract_code_details(doc, ns, "//hl7:raceCode"),
      ethnicity: extract_code_details(doc, ns, "//hl7:ethnicGroupCode")
    }
  end

  def self.extract_code_details(doc, ns, xpath)
    node = doc.at_xpath(xpath, ns)
    {
      code: node&.[]("code"),
      display: node&.[]("display"),
      system: node&.[]("codeSystem")
    }
  end
end
