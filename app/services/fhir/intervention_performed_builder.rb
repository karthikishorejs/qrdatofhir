require "fhir_models"
require "securerandom"
require "time"
require_relative "../../constants/fhir_constants"

# InterventionPerformedBuilder builds FHIR Procedure resources for QRDA "Intervention, Performed".
#
# QRDA Template: 2.16.840.1.113883.10.20.24.3.32 (act moodCode="EVN")
#
# Mapping (best-effort):
# - Procedure.status: from QRDA statusCode / negationInd
# - Procedure.code: from QRDA act/code
# - Procedure.subject: Patient
# - Procedure.encounter: linked by controller using extension join logic
# - Procedure.performed[x]: from effectiveTime low/high/value
#
# If an embedded "result" observation exists in QRDA entryRelationship, you should also create a
# separate FHIR Observation resource. (We will expose that via the controller as a second resource
# per QRDA entryRelationship observation.)
class InterventionPerformedBuilder
  def self.build_procedure(performed_data, patient_id, encounter_id: nil)
    proc = FHIR::Procedure.new(
      id: performed_data[:performed_id] || SecureRandom.uuid,
      status: map_status(performed_data),
      subject: FHIR::Reference.new(reference: "Patient/#{patient_id}"),
      code: build_codeable_concept(performed_data[:code]),
      performedDateTime: nil,
      performedPeriod: nil,
      meta: { profile: [ FHIRConstants::QICORE_PROCEDURE_PROFILE ] }
    )

    apply_performed(proc, performed_data[:effective_low], performed_data[:effective_high])
    proc.encounter = FHIR::Reference.new(reference: "Encounter/#{encounter_id}") if encounter_id

    proc
  end

  private

  def self.map_status(performed_data)
    return "not-done" if performed_data[:negation_ind]

    code = performed_data[:status_code].to_s.strip.downcase
    return "completed" if code.empty? || code == "completed"
    return "in-progress" if code == "active" || code == "in-progress"

    "unknown"
  end

  def self.build_codeable_concept(code_hash)
    return nil if code_hash.nil? || code_hash[:code].to_s.strip.empty?

    FHIR::CodeableConcept.new(
      coding: [
        FHIR::Coding.new(
          system: map_code_system(code_hash[:code_system]),
          code: code_hash[:code],
          display: code_hash[:display] || code_hash[:code_system_name]
        )
      ]
    )
  end

  def self.map_code_system(code_system)
    FHIRConstants::CODE_SYSTEM_MAPPINGS[code_system] || code_system
  end

  def self.apply_performed(proc, low, high)
    start_t = parse_time(low)
    end_t = parse_time(high)

    if start_t && end_t
      proc.performedPeriod = FHIR::Period.new(
        start: start_t.iso8601(3),
        end: end_t.iso8601(3)
      )
    elsif start_t
      proc.performedDateTime = start_t.iso8601(3)
    end
  end

  def self.parse_time(value)
    return nil if value.nil?

    v = value.to_s.strip
    return nil if v.empty?

    t =
      if v.match?(/^\d{14}[+-]\d{4}$/)
        Time.strptime(v, "%Y%m%d%H%M%S%z")
      elsif v.match?(/^\d{14}Z$/)
        Time.strptime(v, "%Y%m%d%H%M%SZ")
      elsif v.match?(/^\d{14}$/)
        Time.strptime(v, "%Y%m%d%H%M%S").utc
      elsif v.match?(/^\d{8}$/)
        Time.strptime(v, "%Y%m%d").utc
      else
        Time.parse(v).utc
      end

    t.utc
  rescue StandardError
    nil
  end

  private_class_method :map_status, :build_codeable_concept, :map_code_system, :apply_performed, :parse_time
end
