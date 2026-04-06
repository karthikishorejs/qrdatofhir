require_relative "./medication_active_parser"
require_relative "./medication_administered_parser"
require_relative "./medication_discharge_parser"
require_relative "./medication_order_parser"

# MedicationParser is responsible for extracting medication information from a QRDA document.
#
# This is now an orchestrator that delegates to specialized parsers per QRDA/QDM medication datatype.
class MedicationParser
  def self.extract_medication(doc, ns)
    # Backwards-compatible: return the first medication entry.
    extract_medications(doc, ns).first
  end

  def self.extract_medications(doc, ns)
    MedicationAdministeredParser.extract(doc, ns) +
      MedicationDischargeParser.extract(doc, ns) +
      MedicationOrderParser.extract(doc, ns) +
      MedicationActiveParser.extract(doc, ns)
  end
end
