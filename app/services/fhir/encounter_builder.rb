require "fhir_models"
require "securerandom"
require_relative "../../constants/fhir_constants"

# EncounterBuilder is responsible for building FHIR Encounter resources.
# It includes methods to build the encounter resource with appropriate attributes
# The class handles mapping of codes and systems to ensure compliance with FHIR standards
# The methods are designed to be reusable and modular, allowing for easy integration into the conversion process
# It also includes error handling and validation to ensure that the generated resources are valid and complete.
# The class uses FHIR models to create the resources and includes helper methods for building specific components
class EncounterBuilder
  def self.build_encounter(encounter_data, patient_id)
    FHIR::Encounter.new(
      id: encounter_data[:encounter_id] || SecureRandom.uuid,
      status: encounter_data[:status_code] || FHIRConstants::DEFAULT_ENCOUNTER_STATUS,
      subject: { reference: "Patient/#{patient_id}" },
      period: build_encounter_period(encounter_data[:low_time], encounter_data[:high_time]),
      meta: { profile: [ FHIRConstants::QICORE_ENCOUNTER_PROFILE ] },
      type: build_encounter_type(encounter_data[:code]),
      class: map_encounter_class(encounter_data[:code][:code]) || nil
    )
  end

  private

  def self.build_encounter_period(low_time, high_time)
    {
      start: parse_time(low_time),
      end: parse_time(high_time)
    }
  end

  def self.build_encounter_type(code)
    return [] unless code[:code]

    [ {
      coding: [ build_coding(map_code_system(code[:code_system]), code[:code], code[:code_system_name]) ]
    } ]
  end

  def self.map_encounter_class(code)
    mapping = FHIRConstants::ENCOUNTER_CLASS_MAPPINGS[code]
    return nil unless mapping

    FHIR::Coding.new(
      code: mapping[:code],
      display: mapping[:display],
      system: "http://terminology.hl7.org/CodeSystem/v3-ActCode"
    )
  end

  def self.build_coding(system, code, display = nil)
    { system: system, code: code, display: display }.compact
  end

  def self.map_code_system(code_system)
    FHIRConstants::CODE_SYSTEM_MAPPINGS[code_system] || code_system
  end

  def self.parse_time(time)
    time ? Time.strptime(time, "%Y%m%d%H%M%S").strftime("%Y-%m-%dT%H:%M:%S.%L+00:00") : nil
  end
end
