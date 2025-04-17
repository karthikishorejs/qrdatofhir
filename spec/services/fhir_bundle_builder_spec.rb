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
    it 'builds a QI-Core Encounter with proper patient reference' do
      encounter = described_class.build_encounter("test-patient-1")

      expect(encounter).to be_a(FHIR::Encounter)
      expect(encounter.subject.reference).to eq("Patient/test-patient-1")
      expect(encounter.status).to eq("finished")
      expect(encounter.period.start).to eq("2026-04-07T09:00:00Z")
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
