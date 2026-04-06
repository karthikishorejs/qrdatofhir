require "fhir_models"
require "securerandom"
require_relative "../../constants/fhir_constants"
require_relative "./encounter_builder"
require_relative "./patient_builder"
require_relative "./medication_builder"
require_relative "./medication_request_builder"
require_relative "./medication_statement_builder"
require_relative "./assessment_builder"
require_relative "./intervention_order_builder"
require_relative "./intervention_performed_builder"
require_relative "./procedure_performed_builder"
# FhirBundleBuilder is responsible for building FHIR resources from QRDA data
# It includes methods to build Patient, Encounter, and Medication resources
# Each method constructs the resource with appropriate attributes and extensions
# The class also handles mapping of codes and systems to ensure compliance with FHIR standards
# The methods are designed to be reusable and modular, allowing for easy integration into the conversion process
# The class uses FHIR models to create the resources and includes helper methods for building specific components
# It also includes error handling and validation to ensure that the generated resources are valid and complete
class FhirBundleBuilder
  def self.build_patient(data)
    PatientBuilder.build_patient(data)
  end

  def self.build_encounter(encounter_data, patient_id)
    EncounterBuilder.build_encounter(encounter_data, patient_id)
  end

  def self.build_medication(medication_data, patient_id, encounter_id: nil)
    kind = medication_data[:kind].to_s.strip
    kind = "administered" if kind.empty?

    case kind
    when "order"
      MedicationRequestBuilder.build_request(medication_data, patient_id, encounter_id: encounter_id)
    when "active"
      MedicationStatementBuilder.build_statement(medication_data, patient_id, encounter_id: encounter_id)
    when "discharge"
      # For eCQM measures (including CMS506), "prescribed at discharge" logic commonly expects
      # a MedicationRequest with category=discharge (not a MedicationStatement). Emitting a
      # MedicationRequest here makes the output align with typical QI-Core measure logic.
      MedicationRequestBuilder.build_request(
        medication_data.merge(category: "discharge"),
        patient_id,
        encounter_id: encounter_id
      )
    else
      MedicationBuilder.build_medication(medication_data.merge(encounter_id: encounter_id), patient_id)
    end
  end

  def self.build_assessment(assessment_data, patient_id, encounter_id: nil)
    AssessmentBuilder.build_observation(assessment_data, patient_id, encounter_id: encounter_id)
  end

  def self.build_intervention_order(order_data, patient_id, encounter_id: nil)
    InterventionOrderBuilder.build_service_request(order_data, patient_id, encounter_id: encounter_id)
  end

  def self.build_intervention_performed(performed_data, patient_id, encounter_id: nil)
    InterventionPerformedBuilder.build_procedure(performed_data, patient_id, encounter_id: encounter_id)
  end

  def self.build_procedure_performed(performed_data, patient_id, encounter_id: nil)
    ProcedurePerformedBuilder.build_procedure(performed_data, patient_id, encounter_id: encounter_id)
  end
end
