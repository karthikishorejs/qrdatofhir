require "fhir_models"
require_relative "../../constants/fhir_constants"

# PatientBuilder is responsible for building FHIR Patient resources.
# It includes methods to build the patient resource with appropriate attributes and extensions.
# The class ensures compliance with FHIR standards and provides helper methods for specific components.
class PatientBuilder
  def self.build_patient(data)
    FHIR::Patient.new(
      id: data[:id],
      active: true,
      gender: data[:gender],
      birthDate: format_birth_date(data[:birth_date]),
      name: [ build_name(data[:name]) ],
      meta: { profile: [ FHIRConstants::QICORE_PATIENT_PROFILE ] },
      extension: build_extensions(data)
    )
  end

  private

  def self.build_extensions(data)
    [].tap do |extensions|
      extensions << build_race_extension(data[:race]) if data.dig(:race, :code)
      extensions << build_ethnicity_extension(data[:ethnicity]) if data.dig(:ethnicity, :code)
    end
  end

  def self.build_race_extension(race)
    FHIR::Extension.new(
      url: FHIRConstants::US_CORE_RACE_URL,
      extension: [
        { url: "ombCategory", valueCoding: build_coding(FHIRConstants::OMB_RACE_SYSTEM, race[:code], race[:display]) },
        { url: "text", valueString: race[:display] }
      ]
    )
  end

  def self.build_ethnicity_extension(ethnicity)
    FHIR::Extension.new(
      url: FHIRConstants::US_CORE_ETHNICITY_URL,
      extension: [
        { url: "ombCategory", valueCoding: build_coding(FHIRConstants::OMB_RACE_SYSTEM, ethnicity[:code], ethnicity[:display]) },
        { url: "text", valueString: ethnicity[:display] }
      ]
    )
  end

  def self.build_name(name)
    { use: "usual", given: [ name[:given] ], family: name[:family] }
  end

  def self.format_birth_date(birth)
    return unless birth
    "#{birth[0..3]}-#{birth[4..5]}-#{birth[6..7]}"
  end

  def self.build_coding(system, code, display = nil)
    { system: system, code: code, display: display }.compact
  end
end
