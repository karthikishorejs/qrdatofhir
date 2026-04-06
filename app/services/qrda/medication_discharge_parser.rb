# frozen_string_literal: true
require "securerandom"
require_relative "./status_code_helper"
require_relative "./medication_extraction"

# Extracts discharge medication list items (Act templateId ...24.3.105 with nested SBADM EVN)
class MedicationDischargeParser
  extend StatusCodeHelper

  def self.extract(doc, ns)
    MedicationExtraction.all_substance_administration_nodes(doc, ns).filter_map do |node|
      act = MedicationExtraction.act_ancestor(node, ns)
      next unless act

      act_template_ids = MedicationExtraction.template_ids(act, ns)
      next unless act_template_ids.include?(MedicationExtraction::TPL_MED_DISCHARGE_LIST)

      code_node = MedicationExtraction.code_node(node, ns)
      low_time = MedicationExtraction.effective_low(node, ns)
      high_time = MedicationExtraction.effective_high(node, ns)

      base_id = MedicationExtraction.encounter_group_extension(node, ns)
      suffix_source = (low_time.presence || high_time.presence || SecureRandom.hex(4)).to_s
      suffix = suffix_source.gsub(/[^0-9A-Za-z]/, "")
      medication_id = base_id.present? ? "#{base_id}-#{suffix}" : SecureRandom.uuid

      {
        kind: "discharge",
        medication_id: medication_id,
        encounter_id: base_id.presence,
        low_time: low_time,
        high_time: high_time,
        status_code: map_med_admin_status(MedicationExtraction.status_code(node, ns)),
        code: {
          code: code_node&.[]("code"),
          code_system: code_node&.[]("codeSystem"),
          code_system_name: code_node&.[]("codeSystemName"),
          display: code_node&.[]("displayName")
        }
      }
    end
  end
end
