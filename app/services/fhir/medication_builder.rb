require "fhir_models"
require "securerandom"
require "time"
require_relative "../../constants/fhir_constants"
require_relative "./fhir_id_helper"

# MedicationBuilder is responsible for building FHIR Medication resources
# It includes methods to build the medication resource with appropriate attributes
# The class handles mapping of codes and systems to ensure compliance with FHIR standards
# The methods are designed to be reusable and modular, allowing for easy integration into the conversion process
# It also includes error handling and validation to ensure that the generated resources are valid and complete.
# The class uses FHIR models to create the resources and includes helper methods for building specific components
class MedicationBuilder
  def self.build_medication(medication_data, patient_id)
    patient_id = FhirIdHelper.fhir_id(patient_id)
    medication_id = FhirIdHelper.fhir_id(medication_data[:medication_id]) || SecureRandom.uuid
    status = medication_data[:status_code].to_s.strip
    status = FHIRConstants::DEFAULT_MEDICATION_STATUS if status.empty?

    med = FHIR::MedicationAdministration.new(
      id: medication_id,
      status: status,
      subject: { reference: "Patient/#{patient_id}" },
      effectivePeriod: build_medication_period(medication_data[:low_time], medication_data[:high_time]),
      medicationCodeableConcept: build_medication_codeable_concept(medication_data[:code]),
      meta: { profile: [ FHIRConstants::QICORE_MEDICATION_PROFILE ] }
    )

    # In R4, MedicationAdministration uses `context` to reference the encounter/episode of care.
    encounter_id = FhirIdHelper.fhir_id(medication_data[:encounter_id])
    if encounter_id
      med.context = FHIR::Reference.new(reference: "Encounter/#{encounter_id}")
    end

    med
  end

  private

  def self.build_medication_period(low_time, high_time)
    period = {
      start: parse_time(low_time),
      end: parse_time(high_time)
    }.compact
    period.empty? ? nil : period
  end

  def self.build_medication_codeable_concept(code)
    if code.nil? || code[:code].nil? || code[:code].to_s.strip.empty?
      return {
        coding: [
          build_coding(FHIRConstants::RXNORM_SYSTEM, FHIRConstants::DEFAULT_MEDICATION_CODE)
        ]
      }
    end

    {
      coding: [
        build_coding(
          map_code_system(code[:code_system]),
          code[:code],
          code[:display] || code[:code_system_name]
        )
      ]
    }
  end

  def self.build_coding(system, code, display = nil)
    { system: system, code: code, display: display }.compact
  end

  def self.map_code_system(code_system)
    FHIRConstants::CODE_SYSTEM_MAPPINGS[code_system] || code_system
  end

  def self.parse_time(time)
    return nil if time.nil? || time.strip.empty?

    t = time.strip

    parsed =
      if t.match?(/^\d{14}[+-]\d{4}$/) # 20260101123000-0500
        Time.strptime(t, "%Y%m%d%H%M%S%z")
      elsif t.match?(/^\d{14}Z$/) # 20260101123000Z
        Time.strptime(t, "%Y%m%d%H%M%SZ")
      elsif t.match?(/^\d{14}$/) # 20260101123000
        Time.strptime(t, "%Y%m%d%H%M%S").utc
      elsif t.match?(/^\d{8}$/) # 20260101
        Time.strptime(t, "%Y%m%d").utc
      else
        begin
          Time.parse(t).utc
        rescue StandardError
          return nil
        end
      end

    parsed.utc.iso8601(3)
  end
end
