require "securerandom"

# InterventionOrderParser extracts "Intervention, Order" (QDM) entries from a QRDA Category I document.
#
# QRDA Template:
#   Intervention order (V6)
#   templateId root = 2.16.840.1.113883.10.20.24.3.31
#
# Source template generator reference: app/templates/inv_order.py
# The act is: <act classCode="ACT" moodCode="RQO">
#
# Convention used in your QRDA: act/id/@extension is the encounter-group join key.
class InterventionOrderParser
  TEMPLATE_ROOT = "2.16.840.1.113883.10.20.24.3.31".freeze

  def self.extract_orders(doc, ns)
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
          order_id_root: root,
          order_id_extension: ext,
          order_id: build_instance_id(root, ext, effective_low, effective_high),
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
          }
        }
      end
  end

  def self.extract_order(doc, ns)
    extract_orders(doc, ns).first
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

  private_class_method :build_instance_id
end
