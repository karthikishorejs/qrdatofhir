require "securerandom"

# InterventionPerformedParser extracts "Intervention, Performed" (QDM) entries from a QRDA Category I document.
#
# QRDA Template:
#   Intervention performed (V6)
#   templateId root = 2.16.840.1.113883.10.20.24.3.32
#
# Source template generator reference: app/templates/inv_performed.py
# The act is: <act classCode="ACT" moodCode="EVN">
#
# Convention used in your QRDA: act/id/@extension is the encounter-group join key.
class InterventionPerformedParser
  TEMPLATE_ROOT = "2.16.840.1.113883.10.20.24.3.32".freeze

  def self.extract_performed(doc, ns)
    doc
      .xpath("//hl7:act[hl7:templateId[@root='#{TEMPLATE_ROOT}']]", ns)
      .map do |act|
        id_node = act.at_xpath("hl7:id", ns)
        ext = id_node&.[]("extension")
        root = id_node&.[]("root")

        code_node = act.at_xpath("hl7:code", ns)

        low_time = act.at_xpath("hl7:effectiveTime/hl7:low", ns)&.[]("value")
        high_time = act.at_xpath("hl7:effectiveTime/hl7:high", ns)&.[]("value")
        time_value = act.at_xpath("hl7:effectiveTime", ns)&.[]("value")

        effective_low = low_time || time_value
        effective_high = high_time

        negation_ind = act["negationInd"] == "true"
        status_code = act.at_xpath("hl7:statusCode", ns)&.[]("code")&.to_s&.strip

        {
          performed_id_root: root,
          performed_id_extension: ext,
          performed_id: build_instance_id(root, ext, effective_low, effective_high),
          encounter_extension: ext,
          negation_ind: negation_ind,
          status_code: status_code,
          effective_low: effective_low,
          effective_high: effective_high,
          code: {
            code: code_node&.[]("code"),
            code_system: code_node&.[]("codeSystem"),
            code_system_name: code_node&.[]("codeSystemName"),
            display: code_node&.[]("displayName")
          },
          # Optional: Result observation embedded as entryRelationship/observation
          result: extract_result_observation(act, ns)
        }
      end
  end

  def self.extract_one(doc, ns)
    extract_performed(doc, ns).first
  end

  def self.extract_result_observation(act, ns)
    obs = act.at_xpath("hl7:entryRelationship[@typeCode='REFR']/hl7:observation", ns)
    return nil unless obs

    code_node = obs.at_xpath("hl7:code", ns)
    value_node = obs.at_xpath("hl7:value", ns)

    low_time = obs.at_xpath("hl7:effectiveTime/hl7:low", ns)&.[]("value")
    high_time = obs.at_xpath("hl7:effectiveTime/hl7:high", ns)&.[]("value")
    time_value = obs.at_xpath("hl7:effectiveTime", ns)&.[]("value")

    {
      code: {
        code: code_node&.[]("code"),
        code_system: code_node&.[]("codeSystem"),
        code_system_name: code_node&.[]("codeSystemName"),
        display: code_node&.[]("displayName")
      },
      effective_low: low_time || time_value,
      effective_high: high_time,
      value: extract_value(value_node)
    }
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
    base = extension.to_s.strip
    base = root.to_s.strip if base.empty?
    base = SecureRandom.uuid if base.empty?

    suffix_source = [low, high].compact.join("-")
    suffix_source = SecureRandom.hex(4) if suffix_source.strip.empty?
    suffix = suffix_source.gsub(/[^0-9A-Za-z]/, "")
    "#{base}-#{suffix}"
  end

  private_class_method :extract_result_observation, :extract_value, :build_instance_id
end
