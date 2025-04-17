require "fhir_models"
require "securerandom"

class FhirBundleBuilder
  def self.build_patient(data)
    patient = FHIR::Patient.new(
      id: data[:id],
      active: true,
      gender: data[:gender],
      birthDate: format_birth_date(data[:birth_date]),
      name: [ build_name(data[:name]) ],
      meta: {
        profile: [ "http://hl7.org/fhir/us/qicore/StructureDefinition/qicore-patient" ]
      },
      extension: build_extensions(data)
    )

    patient
  end

  def self.build_encounter(encounter_data, patient_id)
    FHIR::Encounter.new(
      id: encounter_data[:encounter_id] || SecureRandom.uuid,
      status: encounter_data[:status_code] || "unknown",
      subject: { reference: "Patient/#{patient_id}" },
      period: build_encounter_period(encounter_data[:low_time], encounter_data[:high_time]),
      meta: {
        profile: [ "http://hl7.org/fhir/us/qicore/StructureDefinition/qicore-encounter" ]
      },
      type: encounter_data[:code][:code] ? [
        {
          coding: [
            {
              system: map_code_system(encounter_data[:code][:code_system]),
              code: encounter_data[:code][:code],
              display: encounter_data[:code][:code_system_name]
            }
          ]
        }
      ] : [],
      class: map_encounter_class(encounter_data[:code][:code]) || nil,
    )
  end

  def self.build_medication(patient_id)
    FHIR::MedicationAdministration.new(
      id: SecureRandom.uuid,
      status: "completed",
      subject: { reference: "Patient/#{patient_id}" },
      effectivePeriod: build_medication_period,
      medicationCodeableConcept: build_medication_codeable_concept,
      meta: {
        profile: [ "http://hl7.org/fhir/us/qicore/StructureDefinition/qicore-medicationadministration" ]
      }
    )
  end

  private

  def self.build_extensions(data)
    extensions = []
    extensions << build_race_extension(data[:race]) if data[:race][:code]
    extensions << build_ethnicity_extension(data[:ethnicity]) if data[:ethnicity][:code]
    extensions
  end

  def self.build_race_extension(race)
    FHIR::Extension.new(
      url: "http://hl7.org/fhir/us/core/StructureDefinition/us-core-race",
      extension: [
        {
          url: "ombCategory",
          valueCoding: {
            system: "urn:oid:2.16.840.1.113883.6.238",
            code: race[:code],
            display: race[:display]
          }
        },
        {
          url: "text",
          valueString: race[:display]
        }
      ]
    )
  end

  def self.build_ethnicity_extension(ethnicity)
    FHIR::Extension.new(
      url: "http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity",
      extension: [
        {
          url: "ombCategory",
          valueCoding: {
            system: "urn:oid:2.16.840.1.113883.6.238",
            code: ethnicity[:code],
            display: ethnicity[:display]
          }
        },
        {
          url: "text",
          valueString: ethnicity[:display]
        }
      ]
    )
  end

  def self.build_name(name)
    {
      use: "usual",
      given: [ name[:given] ],
      family: name[:family]
    }
  end

  def self.build_encounter_period(low_time, high_time)
    {
      start: low_time ? Time.strptime(low_time, "%Y%m%d%H%M%S").utc.iso8601 : nil,
      end: high_time ? Time.strptime(high_time, "%Y%m%d%H%M%S").utc.iso8601 : nil
    }
  end

  def self.build_medication_period
    {
      start: "2026-04-07T08:00:00Z",
      end: "2026-04-07T08:15:00Z"
    }
  end

  def self.build_medication_codeable_concept
    {
      coding: [ {
        system: "http://www.nlm.nih.gov/research/umls/rxnorm",
        code: "1010600"
      } ]
    }
  end

  def self.format_birth_date(birth)
    return unless birth
    "#{birth[0..3]}-#{birth[4..5]}-#{birth[6..7]}"
  end

  def self.map_code_system(code_system)
    case code_system
    when "2.16.840.1.113883.6.96"
      "http://snomed.info/sct"
    when "2.16.840.1.113883.6.1"
      "http://loinc.org"
    when "2.16.840.1.113883.6.88"
      "http://www.nlm.nih.gov/research/umls/rxnorm"
    else
      code_system # Default to the original value if no mapping exists
    end
  end

  def self.map_encounter_class(code)
    case code
    # Encounter, Performed: Encounter Inpatient 2.16.840.1.113883.3.666.5.307
    # Encounter, Performed: Observation Services 2.16.840.1.113762.1.4.1111.143
    when "183452005", "32485007", "8715000", "448951000124107"
      FHIR::Coding.new(
        system: "http://terminology.hl7.org/CodeSystem/v3-ActCode",
        code: "IMP",
        display: "inpatient encounter"
      )
    # Encounter, Performed: Emergency Department Visit 2.16.840.1.113883.3.117.1.7.1.292
    when "4525004"
      FHIR::Coding.new(
        system: "http://terminology.hl7.org/CodeSystem/v3-ActCode",
        code: "EMER",
        display: "emergency"
      )
    when
      nil
    end
  end
end
