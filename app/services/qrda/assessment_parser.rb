require "securerandom"
require_relative "./status_code_helper"

# AssessmentParser extracts "Assessment, Performed" (QDM) entries from a QRDA Category I document.
#
# QRDA Template:
#   Assessment Performed (V4)
#   templateId root = 2.16.840.1.113883.10.20.24.3.144
#
# In many QRDA files, the observation/id/@extension is reused as an encounter/episode join key
# (encounter-group extension). We expose that as `encounter_extension` so the controller can
# associate the resulting FHIR Observation to the correct Encounter segment.
class AssessmentParser
  extend StatusCodeHelper

  TEMPLATE_ROOT = "2.16.840.1.113883.10.20.24.3.144".freeze

  def self.extract_assessments(doc, ns)
    doc
      .xpath("//hl7:observation[hl7:templateId[@root='#{TEMPLATE_ROOT}']]", ns)
      .map do |obs|
        id_node = obs.at_xpath("hl7:id", ns)
        id_root = id_node&.[]("root")
        id_extension = id_node&.[]("extension")

        code_node = obs.at_xpath("hl7:code", ns)
        value_node = obs.at_xpath("hl7:value", ns)

        low_time = obs.at_xpath("hl7:effectiveTime/hl7:low", ns)&.[]("value")
        high_time = obs.at_xpath("hl7:effectiveTime/hl7:high", ns)&.[]("value")
        time_value = obs.at_xpath("hl7:effectiveTime", ns)&.[]("value")

        effective_low = low_time || time_value
        effective_high = high_time

        negation_ind = obs["negationInd"] == "true"

        {
          assessment_id_root: id_root,
          assessment_id_extension: id_extension,
          assessment_id: build_instance_id(id_root, id_extension, effective_low, effective_high),
          # Used as the join key to an encounter-group (per your QRDA conventions)
          encounter_extension: id_extension,
          negation_ind: negation_ind,
          status_code: obs.at_xpath("hl7:statusCode", ns)&.[]("code")&.to_s&.strip,
          effective_low: effective_low,
          effective_high: effective_high,
          code: {
            code: code_node&.[]("code"),
            code_system: code_node&.[]("codeSystem"),
            code_system_name: code_node&.[]("codeSystemName"),
            display: code_node&.[]("displayName")
          },
          value: extract_value(value_node)
        }
      end
  end

  def self.extract_assessment(doc, ns)
    extract_assessments(doc, ns).first
  end

  def self.extract_value(value_node)
    return nil unless value_node

    {
      type: value_node&.[]("xsi:type") || value_node&.[]("type"),
      code: value_node&.[]("code"),
      code_system: value_node&.[]("codeSystem"),
      display: value_node&.[]("displayName"),
      value: value_node&.[]("value")
    }.compact
  end

  def self.build_instance_id(root, extension, low, high)
    # QRDA ids are often reused; ensure uniqueness per resource instance.
    base = extension.to_s.strip
    base = root.to_s.strip if base.empty?
    base = SecureRandom.uuid if base.empty?

    suffix_source = [low, high].compact.join("-")
    suffix_source = SecureRandom.hex(4) if suffix_source.strip.empty?
    suffix = suffix_source.gsub(/[^0-9A-Za-z]/, "")

    "#{base}-#{suffix}"
  end

  private_class_method :extract_value, :build_instance_id
end
