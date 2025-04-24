require "fhir_models"
require "securerandom"
require_relative "../../constants/fhir_constants"
require_relative "./encounter_builder"
require_relative "./patient_builder"
require_relative "./medication_builder"
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

  def self.build_medication(medication_data, patient_id)
    MedicationBuilder.build_medication(medication_data, patient_id)
  end
end
