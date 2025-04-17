require 'nokogiri'
require 'securerandom'

class QrdaParser
  attr_reader :doc, :ns

  def initialize(file)
    @doc = Nokogiri::XML(file)
    @ns = { 'hl7' => 'urn:hl7-org:v3' }
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

  private

  def extract_patient_id
    doc.at_xpath('//hl7:patientRole/hl7:id', ns)&.[]('extension') || SecureRandom.uuid
  end

  def extract_birth_date
    doc.at_xpath('//hl7:birthTime', ns)&.[]('value')
  end

  def extract_gender
    doc.at_xpath('//hl7:administrativeGenderCode', ns)&.[]('code')&.downcase || 'unknown'
  end

  def extract_name
    {
      given: doc.at_xpath('//hl7:patient/hl7:name/hl7:given', ns)&.text,
      family: doc.at_xpath('//hl7:patient/hl7:name/hl7:family', ns)&.text
    }
  end

  def extract_race_and_ethnicity
    {
      race: extract_code_details('//hl7:raceCode'),
      ethnicity: extract_code_details('//hl7:ethnicGroupCode')
    }
  end

  def extract_code_details(xpath)
    node = doc.at_xpath(xpath, ns)
    {
      code: node&.[]('code'),
      display: node&.[]('display'),
      system: node&.[]('codeSystem')
    }
  end
end