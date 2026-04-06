require "fhir_models"
require "securerandom"
require "time"
require_relative "../../constants/fhir_constants"
require_relative "../qrda/status_code_helper"
require_relative "./fhir_id_helper"

# MedicationRequestBuilder builds FHIR MedicationRequest resources (Medication, Order).
class MedicationRequestBuilder
  def self.build_request(medication_data, patient_id, encounter_id: nil)
    patient_id = FhirIdHelper.fhir_id(patient_id)
    encounter_id = FhirIdHelper.fhir_id(encounter_id) if encounter_id
    medication_id = FhirIdHelper.fhir_id(medication_data[:medication_id]) || SecureRandom.uuid

    # Some measures expect discharge meds to be represented as MedicationRequest with
    # category=discharge.
    category = build_category(medication_data[:category])

    req = FHIR::MedicationRequest.new(
      id: medication_id,
      status: map_status(medication_data),
      intent: "order",
      category: category,
      subject: { reference: "Patient/#{patient_id}" },
      medicationCodeableConcept: build_medication_codeable_concept(medication_data[:code]),
      authoredOn: parse_time(medication_data[:low_time]),
      meta: { profile: [ FHIRConstants::QICORE_MEDICATION_REQUEST_PROFILE ] }
    )

    req.encounter = FHIR::Reference.new(reference: "Encounter/#{encounter_id}") if encounter_id

    req
  end

  private

  def self.map_status(medication_data)
    StatusCodeHelper.map_med_request_status(
      medication_data[:status_code],
      negation_ind: medication_data[:negation_ind]
    )
  end

  def self.build_category(category)
    return nil if category.nil?

    case category.to_s
    when "discharge"
      [
        FHIR::CodeableConcept.new(
          coding: [
            FHIR::Coding.new(
              system: "http://terminology.hl7.org/CodeSystem/medicationrequest-category",
              code: "discharge",
              display: "Discharge"
            )
          ]
        )
      ]
    else
      nil
    end
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
