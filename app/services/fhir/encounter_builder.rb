require "fhir_models"
require "securerandom"
require "time"
require_relative "../../constants/fhir_constants"
require_relative "./condition_builder"
require_relative "./fhir_id_helper"

# EncounterBuilder is responsible for building FHIR Encounter resources.
# It includes methods to build the encounter resource with appropriate attributes
# The class handles mapping of codes and systems to ensure compliance with FHIR standards
# The methods are designed to be reusable and modular, allowing for easy integration into the conversion process
# It also includes error handling and validation to ensure that the generated resources are valid and complete.
# The class uses FHIR models to create the resources and includes helper methods for building specific components
class EncounterBuilder
  def self.build_encounter(encounter_data, patient_id)
    patient_id = FhirIdHelper.fhir_id(patient_id)
    code_hash = encounter_data[:code] || {}
    encounter_status = encounter_data[:status_code].to_s.strip
    encounter_status = FHIRConstants::DEFAULT_ENCOUNTER_STATUS if encounter_status.empty?
    # Side channel: if present, we'll push Condition resources created for diagnoses here.
    # ConversionsController can persist them alongside the Encounter JSON.
    @last_conditions = []

    enc = FHIR::Encounter.new(
      id: build_encounter_id(encounter_data),
      status: encounter_status,
      subject: { reference: "Patient/#{patient_id}" },
      period: build_encounter_period(encounter_data[:low_time], encounter_data[:high_time]),
      meta: { profile: [ FHIRConstants::QICORE_ENCOUNTER_PROFILE ] },
      type: build_encounter_type(code_hash),
      class: map_encounter_class(code_hash[:code], valueset_hint: encounter_data[:valueset_hint]) || nil,
      hospitalization: FHIR::Encounter::Hospitalization.new(
        dischargeDisposition: build_discharge_disposition(
          encounter_data[:discharge_disposition] || encounter_data.dig(:hospitalization, :discharge_disposition)
        ),
        admitSource: build_admit_source(encounter_data[:admit_source])
      ),
      location: build_locations(encounter_data[:facility_locations])
    )

    build_diagnosis_conditions(enc, encounter_data[:diagnoses], patient_id)

    enc
  end

  def self.last_conditions
    @last_conditions || []
  end

  private

  def self.build_encounter_id(encounter_data)
    ext = FhirIdHelper.fhir_id(encounter_data[:encounter_id_extension] || encounter_data[:encounter_id])
    code = FhirIdHelper.fhir_id(encounter_data.dig(:code, :code))

    # In your QRDA, multiple Encounter entries often share the same `id/@extension`
    # (episode/group id). To keep multiple Encounter *resources* without FHIR id
    # collisions, we derive a stable unique id using:
    #   <extension>-<encounter-code>
    #
    # If code is missing, we fall back to extension alone, and finally UUID.
    if ext && !ext.empty? && code && !code.empty?
      "#{ext}-#{code}"
    elsif ext && !ext.empty?
      ext
    else
      SecureRandom.uuid
    end
  end


  def self.build_encounter_period(low_time, high_time)
    period = {
      start: parse_time(low_time),
      end: parse_time(high_time)
    }.compact
    period.empty? ? nil : period
  end

  def self.build_encounter_type(code)
    code ||= {}
    return [] unless code[:code]

    [ {
      coding: [ build_coding(map_code_system(code[:code_system]), code[:code], code[:display] || code[:code_system_name]) ]
    } ]
  end

  def self.map_encounter_class(code, valueset_hint: nil)
    # Prefer valueset-hint from QRDA comments when present (per your guidance):
    # - 292 => EMER
    # - 307 => IMP
    # - 424 => IMP (Non-elective inpatient encounter)
    case valueset_hint.to_s
    when "292"
      return FHIR::Coding.new(
        code: "EMER",
        display: "emergency",
        system: "http://terminology.hl7.org/CodeSystem/v3-ActCode"
      )
    when "307"
      return FHIR::Coding.new(
        code: "IMP",
        display: "inpatient encounter",
        system: "http://terminology.hl7.org/CodeSystem/v3-ActCode"
      )
    when "424"
      return FHIR::Coding.new(
        code: "IMP",
        display: "inpatient encounter",
        system: "http://terminology.hl7.org/CodeSystem/v3-ActCode"
      )
    end

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

  def self.build_admit_source(admit_source)
    return nil unless admit_source && admit_source[:code]

    FHIR::CodeableConcept.new(
      coding: [
        FHIR::Coding.new(
          system: map_code_system(admit_source[:code_system]),
          code: admit_source[:code],
          display: admit_source[:display] || admit_source[:code_system_name]
        )
      ]
    )
  end

  def self.build_locations(facility_locations)
    return nil if facility_locations.nil? || facility_locations.empty?

    facility_locations.map do |loc|
      code = loc[:code] || {}
      next nil unless code[:code]

      FHIR::Encounter::Location.new(
        location: {
          # We don't have enough data to generate a FHIR Location resource yet, so we store the code in display.
          display: code[:display] || code[:code]
        },
        period: {
          start: parse_time(loc[:low_time]),
          end: parse_time(loc[:high_time])
        }.compact
      )
    end.compact
  end

  def self.build_diagnosis_conditions(encounter, diagnoses, patient_id)
    return if diagnoses.nil? || diagnoses.empty?

    diagnoses.each do |d|
      condition = ConditionBuilder.build_condition(
        d,
        patient_id,
        encounter_id: encounter.id
      )

      @last_conditions << condition
    end
  end

  def self.build_discharge_disposition(discharge_disposition)
    return nil unless discharge_disposition

    codings = []

    source_coding = build_source_discharge_disposition_coding(discharge_disposition)
    codings << source_coding if source_coding

    mapping = FHIRConstants::DISCHARGE_DISPOSITION_MAPPINGS[discharge_disposition[:code]]
    if mapping
      mapped_coding =
        FHIR::Coding.new(
          code: mapping["code"],
          display: mapping["display"],
          system: mapping["system"]
        )

      duplicate_mapping = codings.any? do |coding|
        coding.system == mapped_coding.system && coding.code == mapped_coding.code
      end
      codings << mapped_coding unless duplicate_mapping
    end

    return nil if codings.empty?

    FHIR::CodeableConcept.new(
      coding: codings
    )
  end

  def self.build_source_discharge_disposition_coding(discharge_disposition)
    code = discharge_disposition[:code].to_s.strip
    system = map_code_system(discharge_disposition[:code_system])

    return nil if code.empty? || system.to_s.strip.empty?

    FHIR::Coding.new(
      code: code,
      display: discharge_disposition[:display] || discharge_disposition[:code_system_name],
      system: system
    )
  end
end
