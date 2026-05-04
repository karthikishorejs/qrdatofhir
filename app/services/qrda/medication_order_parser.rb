# frozen_string_literal: true
require_relative "./status_code_helper"
require_relative "./medication_extraction"

# Extracts medication orders (moodCode RQO or templateId ...24.3.47)
class MedicationOrderParser
  extend StatusCodeHelper

  def self.extract(doc, ns)
    MedicationExtraction.all_substance_administration_nodes(doc, ns).filter_map do |node|
      template_ids = MedicationExtraction.template_ids(node, ns)
      act = MedicationExtraction.act_ancestor(node, ns)
      act_mood_code = act&.[]("moodCode")
      act_template_ids = act ? MedicationExtraction.template_ids(act, ns) : []

      # Do not treat discharge medication lists as generic MedicationRequest orders.
      # In QRDA/CDA, discharge meds are frequently wrapped in an Act with moodCode="RQO",
      # but semantically they represent a discharge med list item (mapped separately).
      next if act_template_ids.include?(MedicationExtraction::TPL_MED_DISCHARGE_LIST)

      is_order = node["moodCode"].to_s == "RQO" ||
                 act_mood_code.to_s == "RQO" ||
                 template_ids.include?(MedicationExtraction::TPL_MED_ORDER)

      next unless is_order

      code_node = MedicationExtraction.code_node(node, ns)
      low_time = MedicationExtraction.effective_low(node, ns)
      high_time = MedicationExtraction.effective_high(node, ns)

      base_id = MedicationExtraction.encounter_group_extension(node, ns)
      medication_id =
        MedicationExtraction.medication_id(
          node,
          ns,
          low_time: low_time,
          high_time: high_time,
          code_node: code_node
        )

      {
        kind: "order",
        medication_id: medication_id,
        encounter_id: MedicationExtraction.first_present(base_id),
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
