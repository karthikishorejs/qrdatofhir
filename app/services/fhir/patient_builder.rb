require "fhir_models"
require_relative "../../constants/fhir_constants"
require_relative "./fhir_id_helper"

# PatientBuilder is responsible for building FHIR Patient resources.
# It includes methods to build the patient resource with appropriate attributes and extensions.
# The class ensures compliance with FHIR standards and provides helper methods for specific components.
class PatientBuilder
  def self.build_patient(data)
    FHIR::Patient.new(
      id: FhirIdHelper.fhir_id(data[:id]),
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
    name ||= {}

    given =
      case name[:given]
      when Array
        name[:given].compact.map(&:to_s).reject(&:empty?)
      when nil
        []
      else
        [ name[:given].to_s ].reject(&:empty?)
      end

    { use: "usual", given: given, family: name[:family] }.compact
  end

  def self.format_birth_date(birth)
    return nil if birth.nil?

    b = birth.to_s.strip
    return nil if b.empty?

    # QRDA birthTime often appears as:
    # - YYYYMMDD
    # - YYYYMM
    # - YYYY
    # but sometimes includes time (e.g. YYYYMMDDHHMM / YYYYMMDDHHMMSS).
    #
    # FHIR Patient.birthDate is a *date* (YYYY-MM-DD), not a datetime.
    digits = b.gsub(/[^0-9]/, "")

    # If we have at least YYYYMMDD, use that and ignore any trailing time.
    if digits.length >= 8
      d = digits[0, 8]
      return "#{d[0..3]}-#{d[4..5]}-#{d[6..7]}"
    end

    case digits.length
    when 6
      "#{digits[0..3]}-#{digits[4..5]}"
    when 4
      digits
    else
      # Best-effort fallback (may still be invalid, but avoids raising).
      b
    end
  end

  def self.build_coding(system, code, display = nil)
    { system: system, code: code, display: display }.compact
  end
end
