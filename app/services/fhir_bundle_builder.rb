require 'fhir_models'
require 'securerandom'

class FhirBundleBuilder
  def self.build_patient(data)
    patient = FHIR::Patient.new(
      id: data[:id],
      active: true,
      gender: data[:gender],
      birthDate: format_birth_date(data[:birth_date]),
      name: [build_name(data[:name])],
      meta: {
        profile: ['http://hl7.org/fhir/us/qicore/StructureDefinition/qicore-patient']
      },
      extension: build_extensions(data)
    )

    patient
  end

  def self.build_encounter(patient_id)
    FHIR::Encounter.new(
      id: SecureRandom.uuid,
      status: 'finished',
      subject: { reference: "Patient/#{patient_id}" },
      period: build_encounter_period,
      meta: {
        profile: ['http://hl7.org/fhir/us/qicore/StructureDefinition/qicore-encounter']
      }
    )
  end

  def self.build_medication(patient_id)
    FHIR::MedicationAdministration.new(
      id: SecureRandom.uuid,
      status: 'completed',
      subject: { reference: "Patient/#{patient_id}" },
      effectivePeriod: build_medication_period,
      medicationCodeableConcept: build_medication_codeable_concept,
      meta: {
        profile: ['http://hl7.org/fhir/us/qicore/StructureDefinition/qicore-medicationadministration']
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
      url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race',
      extension: [
        {
          url: 'ombCategory',
          valueCoding: {
            system: 'urn:oid:2.16.840.1.113883.6.238',
            code: race[:code],
            display: race[:display]
          }
        },
        {
          url: 'text',
          valueString: race[:display]
        }
      ]
    )
  end

  def self.build_ethnicity_extension(ethnicity)
    FHIR::Extension.new(
      url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity',
      extension: [
        {
          url: 'ombCategory',
          valueCoding: {
            system: 'urn:oid:2.16.840.1.113883.6.238',
            code: ethnicity[:code],
            display: ethnicity[:display]
          }
        },
        {
          url: 'text',
          valueString: ethnicity[:display]
        }
      ]
    )
  end

  def self.build_name(name)
    {
      use: 'usual',
      given: [name[:given]],
      family: name[:family]
    }
  end

  def self.build_encounter_period
    {
      start: "2026-04-07T09:00:00Z",
      end: "2026-04-10T08:15:00Z"
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
      coding: [{
        system: "http://www.nlm.nih.gov/research/umls/rxnorm",
        code: "1010600"
      }]
    }
  end

  def self.format_birth_date(birth)
    return unless birth
    "#{birth[0..3]}-#{birth[4..5]}-#{birth[6..7]}"
  end
end
