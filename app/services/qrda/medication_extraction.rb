# frozen_string_literal: true
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
end
