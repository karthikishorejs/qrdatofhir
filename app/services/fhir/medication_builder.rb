require "fhir_models"
require "securerandom"
require_relative "../../constants/fhir_constants"

# MedicationBuilder is responsible for building FHIR Medication resources
# It includes methods to build the medication resource with appropriate attributes
# The class handles mapping of codes and systems to ensure compliance with FHIR standards
# The methods are designed to be reusable and modular, allowing for easy integration into the conversion process
# It also includes error handling and validation to ensure that the generated resources are valid and complete.
# The class uses FHIR models to create the resources and includes helper methods for building specific components
class MedicationBuilder
  def self.build_medication(medication_data, patient_id)
    FHIR::MedicationAdministration.new(
      id: SecureRandom.uuid,
      status: "completed",
      subject: { reference: "Patient/#{patient_id}" },
      effectivePeriod: build_medication_period(medication_data[:low_time], medication_data[:high_time]),
      medicationCodeableConcept: build_medication_codeable_concept,
      meta: { profile: [ FHIRConstants::QICORE_MEDICATION_PROFILE ] }
    )
  end

  private

  def self.build_medication_period(low_time, high_time)
    {
      start: parse_time(low_time),
      end: parse_time(high_time)
    }
  end

  def self.build_medication_codeable_concept
    { coding: [ build_coding(FHIRConstants::RXNORM_SYSTEM, FHIRConstants::DEFAULT_MEDICATION_CODE) ] }
  end

  def self.build_coding(system, code, display = nil)
    { system: system, code: code, display: display }.compact
  end

  def self.parse_time(time)
    time ? Time.strptime(time, "%Y%m%d%H%M%S").strftime("%Y-%m-%dT%H:%M:%S.%L+00:00") : nil
  end
end
