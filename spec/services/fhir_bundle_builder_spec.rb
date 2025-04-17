require 'rails_helper'

RSpec.describe FhirBundleBuilder, type: :service do
  let(:test_data) do
    {
      id: "test-patient-1",
      gender: "female",
      birth_date: "19910302190000",
      name: {
        given: "Jane",
        family: "Doe"
      },
      race: {
        code: "1002-5",
        display: "Asian"
      },
      ethnicity: {
        code: "2135-2",
        display: "Hispanic or Latino"
      }
    }
  end

  describe '.build_patient' do
    it 'builds a QI-Core conformant patient with correct name and extensions' do
      patient = described_class.build_patient(test_data)

      expect(patient).to be_a(FHIR::Patient)
      expect(patient.id).to eq("test-patient-1")
      expect(patient.gender).to eq("female")
      expect(patient.birthDate).to eq("1991-03-02")

      name = patient.name.first
      expect(name.given).to include("Jane")
      expect(name.family).to eq("Doe")

      race_ext = patient.extension.find { |ext| ext.url.include?('us-core-race') }
      expect(race_ext).to be_present
      expect(race_ext.extension.any? { |e| e.url == 'ombCategory' && e.valueCoding.code == "1002-5" }).to be true
    end
  end

  describe '.build_encounter' do
    let(:patient_id) { '12345' }

    context 'when encounter data is valid' do
      let(:encounter_data) do
        {
          encounter_id: 'encounter-1',
          status_code: 'finished',
          low_time: '20240219115139',
          high_time: '20240219120639',
          code: {
            code: '183452005',
            code_system: '2.16.840.1.113883.6.96',
            code_system_name: 'SNOMEDCT'
          }
        }
      end

      it 'builds a valid FHIR Encounter resource' do
        encounter = FhirBundleBuilder.build_encounter(encounter_data, patient_id)

        expect(encounter.id).to eq('encounter-1')
        expect(encounter.status).to eq('finished')
        expect(encounter.subject.reference).to eq("Patient/#{patient_id}")
        expect(encounter.period.start).to eq('2024-02-19T16:51:39Z') # Adjusted to UTC
        expect(encounter.period.end).to eq('2024-02-19T17:06:39Z')   # Adjusted to UTC
        expect(encounter.type.first.coding.first.system).to eq('http://snomed.info/sct')
        expect(encounter.type.first.coding.first.code).to eq('183452005')
        expect(encounter.type.first.coding.first.display).to eq('SNOMEDCT')

        # expect(encounter.class_.code).to eq('IMP')
        # expect(encounter.class_.display).to eq('inpatient encounter')
      end
    end

    context 'when encounter data has an unknown code system' do
      let(:encounter_data) do
        {
          encounter_id: 'encounter-2',
          status_code: 'in-progress',
          low_time: '20240219115139',
          high_time: '20240219120639',
          code: {
            code: '999999',
            code_system: 'unknown-system',
            code_system_name: 'Unknown'
          }
        }
      end

      it 'uses the original code system if no mapping exists' do
        encounter = FhirBundleBuilder.build_encounter(encounter_data, patient_id)

        expect(encounter.type.first.coding.first.system).to eq('unknown-system')
        expect(encounter.type.first.coding.first.code).to eq('999999')
        expect(encounter.type.first.coding.first.display).to eq('Unknown')
        expect(encounter.class).to be_nil
      end
    end

    context 'when encounter data is missing optional fields' do
      let(:encounter_data) do
        {
          encounter_id: nil,
          status_code: nil,
          low_time: nil,
          high_time: nil,
          code: {
            code: nil,
            code_system: nil,
            code_system_name: nil
          }
        }
      end

      it 'builds a FHIR Encounter resource with default values' do
        encounter = FhirBundleBuilder.build_encounter(encounter_data, patient_id)

        expect(encounter.id).not_to be_nil
        expect(encounter.status).to eq('unknown')
        expect(encounter.subject.reference).to eq("Patient/#{patient_id}")
        expect(encounter.period.start).to be_nil
        expect(encounter.period.end).to be_nil
        expect(encounter.type).to eq([])
        expect(encounter.class).to be_nil
      end
    end
  end

  describe '.build_medication' do
    it 'builds a MedicationAdministration with proper coding and patient reference' do
      med = described_class.build_medication("test-patient-1")

      expect(med).to be_a(FHIR::MedicationAdministration)
      expect(med.subject.reference).to eq("Patient/test-patient-1")
      expect(med.status).to eq("completed")
      expect(med.medicationCodeableConcept.coding.first.code).to eq("1010600")
    end
  end
end
