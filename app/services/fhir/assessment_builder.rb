require "fhir_models"
require "securerandom"
require "time"
require_relative "../../constants/fhir_constants"

# AssessmentBuilder builds FHIR Observation resources for QRDA "Assessment, Performed".
#
# QRDA Template:
#   Assessment Performed (V4) templateId 2.16.840.1.113883.10.20.24.3.144
#
# FHIR mapping (best-effort):
# - Observation.status: derived from QRDA statusCode / negationInd
# - Observation.code: QRDA observation/code
# - Observation.subject: Patient reference
# - Observation.effective[x]: effectiveDateTime if single timestamp, else effectivePeriod if low/high
# - Observation.value[x]: if QRDA has a value element (CD/INT/REAL/etc.)
# - Observation.encounter: set by controller using encounter_id resolution logic
class AssessmentBuilder
  def self.build_observation(assessment_data, patient_id, encounter_id: nil)
    obs = FHIR::Observation.new(
      id: assessment_data[:assessment_id] || SecureRandom.uuid,
      status: map_status(assessment_data),
      subject: FHIR::Reference.new(reference: "Patient/#{patient_id}"),
      code: build_codeable_concept(assessment_data[:code]),
      effectiveDateTime: nil,
      effectivePeriod: nil,
      valueCodeableConcept: nil,
      valueQuantity: nil,
      valueString: nil,
      meta: { profile: [ FHIRConstants::QICORE_OBSERVATION_PROFILE ] }
    )

    apply_effective(obs, assessment_data[:effective_low], assessment_data[:effective_high])
    apply_value(obs, assessment_data[:value])

    obs.encounter = FHIR::Reference.new(reference: "Encounter/#{encounter_id}") if encounter_id

    obs
  end

  private

  def self.map_status(assessment_data)
    # QRDA uses statusCode completed for performed. For negationInd (not done),
    # we represent the observation as entered-in-error as a conservative default
    # and rely on downstream extensions/reasoning if needed.
    return "entered-in-error" if assessment_data[:negation_ind]

    code = assessment_data[:status_code].to_s.strip.downcase
    return "final" if code.empty? || code == "completed"

    # Other CDA statuses are uncommon here; fall back to "unknown" if something odd appears.
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

  def self.apply_effective(obs, low, high)
    start_t = parse_time(low)
    end_t = parse_time(high)

    if start_t && end_t
      obs.effectivePeriod = FHIR::Period.new(
        start: start_t.iso8601(3),
        end: end_t.iso8601(3)
      )
    elsif start_t
      obs.effectiveDateTime = start_t.iso8601(3)
    end
  end

  def self.apply_value(obs, value_hash)
    return if value_hash.nil?

    # If the QRDA value is a coded value (CD), map to valueCodeableConcept.
    if value_hash[:code]
      obs.valueCodeableConcept = FHIR::CodeableConcept.new(
        coding: [
          FHIR::Coding.new(
            system: map_code_system(value_hash[:code_system]),
            code: value_hash[:code],
            display: value_hash[:display]
          )
        ]
      )
      return
    end

    # If the QRDA value is a scalar (INT/REAL) it usually appears as value="..."
    if value_hash[:value]
      v = value_hash[:value].to_s
      if v.match?(/\A-?\d+(\.\d+)?\z/)
        obs.valueQuantity = FHIR::Quantity.new(value: v.to_f)
      else
        obs.valueString = v
      end
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

  private_class_method :map_status, :build_codeable_concept, :map_code_system, :apply_effective, :apply_value, :parse_time
end
