# frozen_string_literal: true
require "digest"
require "securerandom"
#
# MedicationExtraction centralizes QRDA medication-node selection and shared field extraction.
#
# QRDA medication content can appear in multiple shapes:
# - Direct entries: <entry><substanceAdministration .../></entry> (often "administered")
# - Nested under an act: <entry><act ...><entryRelationship><substanceAdministration .../></...>
#   (commonly discharge medication lists, and sometimes other medication groupings)
#
module MedicationExtraction
  # Template roots (QDM/QRDA) we key off of
  TPL_MED_ADMINISTERED = "2.16.840.1.113883.10.20.24.3.42"
  TPL_MED_ACTIVE = "2.16.840.1.113883.10.20.24.3.41"
  TPL_MED_ORDER = "2.16.840.1.113883.10.20.24.3.47"
  TPL_MED_DISCHARGE_LIST = "2.16.840.1.113883.10.20.24.3.105"

  def self.all_substance_administration_nodes(doc, ns)
    doc.xpath(
      "//hl7:entry/hl7:substanceAdministration | //hl7:entry/hl7:act//hl7:substanceAdministration",
      ns
    )
  end

  def self.template_ids(node, ns)
    node.xpath("hl7:templateId", ns).map { |t| t["root"] }.compact
  end

  def self.act_ancestor(node, ns)
    node.at_xpath("ancestor::hl7:act[1]", ns)
  end

  def self.status_code(node, ns)
    node.at_xpath("hl7:statusCode", ns)&.[]("code")
  end

  def self.effective_low(node, ns)
    node.at_xpath("hl7:effectiveTime/hl7:low", ns)&.[]("value") ||
      node.at_xpath("hl7:effectiveTime", ns)&.[]("value")
  end

  def self.effective_high(node, ns)
    node.at_xpath("hl7:effectiveTime/hl7:high", ns)&.[]("value")
  end

  def self.code_node(node, ns)
    node.at_xpath(
      "hl7:consumable/hl7:manufacturedProduct/hl7:manufacturedMaterial/hl7:code",
      ns
    )
  end

  def self.encounter_group_extension(node, ns)
    node.at_xpath("hl7:id", ns)&.[]("extension")&.to_s&.strip
  end

  def self.medication_id(node, ns, low_time:, high_time:, code_node:)
    base_id = encounter_group_extension(node, ns)
    timestamp = first_present(low_time, high_time)
    code = code_node&.[]("code")
    source_root = node.at_xpath("hl7:id", ns)&.[]("root")
    seed_parts = [ timestamp, code, code_node&.[]("codeSystem"), source_root ].filter_map do |part|
      value = part.to_s.strip
      value unless value.empty?
    end

    suffix =
      if seed_parts.empty?
        SecureRandom.hex(8)
      else
        readable_parts = [ timestamp, code ].filter_map do |part|
          value = part.to_s.strip
          value unless value.empty?
        end
        readable_parts << Digest::SHA256.hexdigest(seed_parts.join("|"))[0, 8]
        readable_parts.join("-")
      end

    id = first_present(base_id) ? "#{base_id}-#{suffix}" : "medication-#{suffix}"
    fhir_id(id)
  end

  def self.first_present(*values)
    values.find { |value| !value.to_s.strip.empty? }
  end

  def self.fhir_id(raw)
    raw.to_s.strip.tr("_", "-").gsub(/[^A-Za-z0-9\-\.]/, "-")[0, 64]
  end
end
