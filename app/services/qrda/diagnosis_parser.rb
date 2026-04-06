# frozen_string_literal: true
require "securerandom"

# DiagnosisParser extracts standalone diagnosis/problem entries from QRDA.
#
# This is intended for Diagnosis Concern Act / Problem Concern Act entries that appear
# as their own <entry> (not embedded under Encounter).
#
# Common templateIds:
# - Diagnosis Concern Act (V5): 2.16.840.1.113883.10.20.24.3.137
# - Diagnosis / Problem Observation: 2.16.840.1.113883.10.20.24.3.135
#
# Output shape is aligned with ConditionBuilder.build_condition:
# {
#   diagnosis_id: "...",
#   status_code: "...",
#   effective_low: "...",
#   effective_high: "...",
#   diagnosis: { code:, code_system:, code_system_name:, display: }
# }
#
class DiagnosisParser
  TPL_DIAGNOSIS_CONCERN_ACT = "2.16.840.1.113883.10.20.24.3.137"
  TPL_DIAGNOSIS_OBSERVATION = "2.16.840.1.113883.10.20.24.3.135"

  def self.extract_diagnoses(doc, ns)
    doc.xpath("//hl7:entry/hl7:act", ns).filter_map do |act|
      act_template_ids = act.xpath("hl7:templateId", ns).map { |t| t["root"] }.compact
      next unless act_template_ids.include?(TPL_DIAGNOSIS_CONCERN_ACT)

      obs = act.at_xpath("hl7:entryRelationship/hl7:observation", ns)
      next unless obs

      obs_template_ids = obs.xpath("hl7:templateId", ns).map { |t| t['root'] }.compact
      next unless obs_template_ids.include?(TPL_DIAGNOSIS_OBSERVATION)

      # Diagnosis code is stored in observation/value (CD)
      value_node = obs.at_xpath("hl7:value", ns)
      code_hash =
        if value_node
          {
            code: value_node["code"],
            code_system: value_node["codeSystem"],
            code_system_name: value_node["codeSystemName"],
            display: value_node["displayName"]
          }
        end

      effective_low = act.at_xpath("hl7:effectiveTime/hl7:low", ns)&.[]("value")
      effective_high = act.at_xpath("hl7:effectiveTime/hl7:high", ns)&.[]("value")

      # Use act id extension/root when available; fall back to UUID
      base_id = act.at_xpath("hl7:id", ns)&.[]("root") || act.at_xpath("hl7:id", ns)&.[]("extension")
      diagnosis_id = base_id.to_s.strip
      diagnosis_id = SecureRandom.uuid if diagnosis_id.empty?

      # QRDA frequently uses id/@extension as the encounter-group key (e.g. "50576109"),
      # same convention used for other resources in this converter.
      encounter_extension = act.at_xpath("hl7:id", ns)&.[]("extension")&.to_s&.strip

      {
        diagnosis_id: diagnosis_id,
        encounter_extension: encounter_extension.presence,
        status_code: obs.at_xpath("hl7:statusCode", ns)&.[]("code") || act.at_xpath("hl7:statusCode", ns)&.[]("code"),
        effective_low: effective_low,
        effective_high: effective_high,
        diagnosis: code_hash
      }
    end
  end
end
