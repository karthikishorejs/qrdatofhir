require "fhir_models"
require "securerandom"
require_relative "../../constants/fhir_constants"
require_relative "./fhir_id_helper"

# ConditionBuilder is responsible for building FHIR Condition resources.
# Used primarily for Encounter.diagnosis references extracted from QRDA.
class ConditionBuilder
  def self.build_condition(diagnosis_data, patient_id, encounter_id: nil)
    patient_id = FhirIdHelper.fhir_id(patient_id)
    encounter_id = FhirIdHelper.fhir_id(encounter_id) if encounter_id
    diagnosis_id = FhirIdHelper.fhir_id(diagnosis_data[:diagnosis_id]) || SecureRandom.uuid
    code = diagnosis_data[:diagnosis] || {}
    coding_system = map_code_system(code[:code_system])

    condition = FHIR::Condition.new(
      id: diagnosis_id,
      subject: { reference: "Patient/#{patient_id}" },
      clinicalStatus: build_clinical_status,
      code: build_codeable_concept(coding_system, code[:code], code[:display]),
      meta: { profile: [ FHIRConstants::QICORE_CONDITION_PROFILE ] }
    )

    condition.encounter = FHIR::Reference.new(reference: "Encounter/#{encounter_id}") if encounter_id

    # If POA exists, store as an extension (profile-specific; using a generic URL placeholder).
    if diagnosis_data[:poa] && diagnosis_data[:poa][:code]
      condition.extension ||= []
      condition.extension << FHIR::Extension.new(
        url: FHIRConstants::QRDA_POA_EXTENSION_URL,
        valueCodeableConcept: FHIR::CodeableConcept.new(
          coding: [
            FHIR::Coding.new(
              system: map_code_system(diagnosis_data[:poa][:code_system]),
              code: diagnosis_data[:poa][:code],
              display: diagnosis_data[:poa][:display]
            )
          ]
        )
      )
    end

    condition
  end

  def self.build_encounter_diagnosis_entry(condition, rank: nil)
    entry = FHIR::Encounter::Diagnosis.new(
      condition: { reference: "Condition/#{condition.id}" }
    )
    entry.rank = rank if rank
    entry
  end

  private

  def self.build_clinical_status
    FHIR::CodeableConcept.new(
      coding: [
        FHIR::Coding.new(
          system: "http://terminology.hl7.org/CodeSystem/condition-clinical",
          code: "active"
        )
      ]
    )
  end

  def self.build_codeable_concept(system, code, display = nil)
    return nil if code.nil? || code.to_s.strip.empty?

    FHIR::CodeableConcept.new(
      coding: [
        FHIR::Coding.new(
          system: system,
          code: code,
          display: display
        )
      ]
    )
  end

  def self.map_code_system(code_system)
    FHIRConstants::CODE_SYSTEM_MAPPINGS[code_system] || code_system
  end
end
