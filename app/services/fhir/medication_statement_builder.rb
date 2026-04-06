require "fhir_models"
require "securerandom"
require "time"
require_relative "../../constants/fhir_constants"
require_relative "../qrda/status_code_helper"
require_relative "./fhir_id_helper"

# MedicationStatementBuilder builds FHIR MedicationStatement resources (Medication, Active / Discharge list).
class MedicationStatementBuilder
  def self.build_statement(medication_data, patient_id, encounter_id: nil)
    patient_id = FhirIdHelper.fhir_id(patient_id)
    encounter_id = FhirIdHelper.fhir_id(encounter_id) if encounter_id
    medication_id = FhirIdHelper.fhir_id(medication_data[:medication_id]) || SecureRandom.uuid

    # QI-Core profile for MedicationStatement isn't always required in every environment,
    # but we at least attach a stable profile when available.
    profile = FHIRConstants.const_defined?(:QICORE_MEDICATION_STATEMENT_PROFILE) ? FHIRConstants::QICORE_MEDICATION_STATEMENT_PROFILE : nil

    stmt = FHIR::MedicationStatement.new(
      id: medication_id,
      status: map_status(medication_data),
      subject: { reference: "Patient/#{patient_id}" },
      medicationCodeableConcept: build_medication_codeable_concept(medication_data[:code]),
      effectivePeriod: build_period(medication_data[:low_time], medication_data[:high_time]),
      meta: { profile: profile ? [ profile ] : [] }
    )

    stmt.context = FHIR::Reference.new(reference: "Encounter/#{encounter_id}") if encounter_id

    stmt
  end

  private

  def self.map_status(medication_data)
    StatusCodeHelper.map_med_statement_status(
      medication_data[:status_code],
      negation_ind: medication_data[:negation_ind]
    )
  end

  def self.build_period(low_time, high_time)
    period = {
      start: parse_time(low_time),
      end: parse_time(high_time)
    }.compact
    period.empty? ? nil : period
  end

  def self.build_medication_codeable_concept(code)
    return nil if code.nil? || code[:code].to_s.strip.empty?

    FHIR::CodeableConcept.new(
      coding: [
        FHIR::Coding.new(
          system: map_code_system(code[:code_system]),
          code: code[:code],
          display: code[:display] || code[:code_system_name]
        )
      ]
    )
  end

  def self.map_code_system(code_system)
    FHIRConstants::CODE_SYSTEM_MAPPINGS[code_system] || code_system
  end

  def self.parse_time(time)
    return nil if time.nil? || time.to_s.strip.empty?

    t = time.to_s.strip

    parsed =
      if t.match?(/^\d{14}[+-]\d{4}$/)
        Time.strptime(t, "%Y%m%d%H%M%S%z")
      elsif t.match?(/^\d{14}Z$/)
        Time.strptime(t, "%Y%m%d%H%M%SZ")
      elsif t.match?(/^\d{14}$/)
        Time.strptime(t, "%Y%m%d%H%M%S").utc
      elsif t.match?(/^\d{8}$/)
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
