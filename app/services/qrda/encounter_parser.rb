require "securerandom"
require_relative "./status_code_helper"

# EncounterParser is responsible for extracting encounter information from a QRDA document.
class EncounterParser
  extend StatusCodeHelper

  def self.extract_encounter(doc, ns)
    # Backwards-compatible: keep returning the first encounter (existing behavior)
    extract_encounters(doc, ns).first
  end

  def self.extract_encounters(doc, ns)
    doc.xpath("//hl7:entry/hl7:encounter", ns).map do |encounter_node|
      valueset_hint = extract_valueset_hint(encounter_node)
      id_node = encounter_node.at_xpath("hl7:id", ns)
      id_root = id_node&.[]("root")
      id_extension = id_node&.[]("extension")

      {
        encounter_id: id_extension || SecureRandom.uuid, # keep for downstream references
        encounter_id_root: id_root,
        encounter_id_extension: id_extension,
        low_time: encounter_node.at_xpath("hl7:effectiveTime/hl7:low", ns)&.[]("value"),
        high_time: encounter_node.at_xpath("hl7:effectiveTime/hl7:high", ns)&.[]("value"),
        status_code: extract_status_code(encounter_node.at_xpath("hl7:statusCode", ns)&.[]("code")),
        code: {
          code: encounter_node.at_xpath("hl7:code", ns)&.[]("code"),
          code_system: encounter_node.at_xpath("hl7:code", ns)&.[]("codeSystem"),
          code_system_name: encounter_node.at_xpath("hl7:code", ns)&.[]("codeSystemName")
        },
        discharge_disposition: extract_discharge_disposition(encounter_node, ns),
        facility_locations: extract_facility_locations(encounter_node, ns),
        admit_source: extract_admit_source(encounter_node, ns),
        diagnoses: extract_diagnoses(encounter_node, ns),
        valueset_hint: valueset_hint
      }
    end
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

  def self.extract_discharge_disposition(encounter_node, ns)
    disposition_node = encounter_node.at_xpath("sdtc:dischargeDispositionCode", ns)
    return nil unless disposition_node
    {
      code: disposition_node&.[]("code"),
      code_system: disposition_node&.[]("codeSystem"),
      code_system_name: disposition_node&.[]("codeSystemName")
    }
  end

  # Facility location participants: <participant typeCode="LOC"> ... <time> ... <participantRole> <code .../>
  def self.extract_facility_locations(encounter_node, ns)
    encounter_node.xpath("hl7:participant[@typeCode='LOC']", ns).map do |participant|
      time = participant.at_xpath("hl7:time", ns)
      role = participant.at_xpath("hl7:participantRole", ns)
      code = role&.at_xpath("hl7:code", ns)

      {
        low_time: time&.at_xpath("hl7:low", ns)&.[]("value"),
        high_time: time&.at_xpath("hl7:high", ns)&.[]("value"),
        code: {
          code: code&.[]("code"),
          code_system: code&.[]("codeSystem"),
          code_system_name: code&.[]("codeSystemName"),
          display: code&.[]("displayName")
        }
      }
    end
  end

  # Admission source participantRole templateId 2.16.840.1.113883.10.20.24.3.151
  def self.extract_admit_source(encounter_node, ns)
    role = encounter_node.at_xpath(
      "hl7:participant[@typeCode='LOC']/hl7:participantRole[hl7:templateId[@root='2.16.840.1.113883.10.20.24.3.151']]",
      ns
    )
    return nil unless role

    code = role.at_xpath("hl7:code", ns)
    return nil unless code

    {
      code: code&.[]("code"),
      code_system: code&.[]("codeSystem"),
      code_system_name: code&.[]("codeSystemName"),
      display: code&.[]("displayName")
    }
  end

  # Diagnoses are embedded as entryRelationship observations in many QRDA files.
  # We try to extract:
  # - diagnosis value code (from observation/value)
  # - POA indicator (if present)
  # - rank (if present)
  def self.extract_diagnoses(encounter_node, ns)
    encounter_node.xpath(".//hl7:entryRelationship/hl7:observation", ns).filter_map do |obs|
      value = obs.at_xpath("hl7:value", ns)
      next nil unless value

      diagnosis = {
        code: value&.[]("code"),
        code_system: value&.[]("codeSystem"),
        display: value&.[]("displayName")
      }

      next nil unless diagnosis[:code]

      {
        diagnosis: diagnosis,
        rank: extract_diagnosis_rank(obs, ns),
        poa: extract_poa_indicator(obs, ns)
      }
    end
  end

  def self.extract_diagnosis_rank(obs, ns)
    rank_val = obs.at_xpath(
      ".//hl7:entryRelationship/hl7:observation/hl7:value[@xsi:type='INT']",
      ns.merge("xsi" => "http://www.w3.org/2001/XMLSchema-instance")
    )
    return nil unless rank_val
    rank_val&.[]("value")&.to_i
  end

  def self.extract_valueset_hint(encounter_node)
    # In many of your QRDA files, the valueset OID/name appears in a comment immediately before <code>.
    # Example:
    # <!--valueset is 2.16.840.1.113883.3.117.1.7.1.292 - valueset name is ...-->
    # <code .../>
    #
    # Nokogiri represents this as a sibling comment node. We'll look at the immediate previous sibling.
    code_node = encounter_node.at_xpath("hl7:code", { "hl7" => "urn:hl7-org:v3" })
    return nil unless code_node

    prev = code_node.previous_sibling
    while prev && prev.text? # skip whitespace
      prev = prev.previous_sibling
    end

    return nil unless prev && prev.comment?

    m = prev.text.match(/1\.7\.1\.(\d{3})/)
    m ? m[1] : nil
  rescue StandardError
    nil
  end

  def self.extract_poa_indicator(obs, ns)
    # POA observation often uses LOINC 78026-2 with a value code.
    poa_obs = obs.at_xpath(".//hl7:entryRelationship/hl7:observation[hl7:code[@code='78026-2']]", ns)
    return nil unless poa_obs
    val = poa_obs.at_xpath("hl7:value", ns)
    return nil unless val

    {
      code: val&.[]("code"),
      code_system: val&.[]("codeSystem"),
      display: val&.[]("displayName")
    }
  end
end
