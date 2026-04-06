require "securerandom"

# ProcedurePerformedParser extracts "Procedure, Performed" (QDM) entries from a QRDA Category I document.
#
# QRDA Template:
#   Procedure, Performed (V7)
#   templateId root = 2.16.840.1.113883.10.20.24.3.64
#
# Source template generator reference: app/templates/proc_performed.py
# The element is: <procedure classCode="PROC" moodCode="EVN">
#
# Convention used in your QRDA: procedure/id/@extension is the encounter-group join key.
class ProcedurePerformedParser
  TEMPLATE_ROOT = "2.16.840.1.113883.10.20.24.3.64".freeze

  ORDINALITY_TEMPLATE_ROOT = "2.16.840.1.113883.10.20.24.3.166".freeze

  def self.extract_performeds(doc, ns)
    doc
      .xpath("//hl7:procedure[hl7:templateId[@root='#{TEMPLATE_ROOT}']]", ns)
      .map do |proc|
        id_node = proc.at_xpath("hl7:id", ns)
        ext = id_node&.[]("extension")
        root = id_node&.[]("root")

        code_node = proc.at_xpath("hl7:code", ns)

        low_time = proc.at_xpath("hl7:effectiveTime/hl7:low", ns)&.[]("value")
        high_time = proc.at_xpath("hl7:effectiveTime/hl7:high", ns)&.[]("value")
        time_value = proc.at_xpath("hl7:effectiveTime", ns)&.[]("value")

        effective_low = low_time || time_value
        effective_high = high_time

        negation_ind = proc["negationInd"] == "true"
        status_code = proc.at_xpath("hl7:statusCode", ns)&.[]("code")&.to_s&.strip

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
          ordinality_rank: extract_ordinality_rank(proc, ns)
        }
      end
  end

  def self.extract_performed(doc, ns)
    extract_performeds(doc, ns).first
  end

  def self.extract_ordinality_rank(proc, ns)
    obs = proc.at_xpath("hl7:entryRelationship[@typeCode='REFR']/hl7:observation[hl7:templateId[@root='#{ORDINALITY_TEMPLATE_ROOT}']]", ns)
    return nil unless obs

    val = obs.at_xpath("hl7:value", ns)
    # Example from template generator:
    # <value xsi:type="INT" value="1"/>
    v = val&.[]("value")
    return nil if v.nil? || v.to_s.strip.empty?

    v.to_i
  rescue StandardError
    nil
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

  private_class_method :extract_ordinality_rank, :build_instance_id
end
