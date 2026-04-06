require "nokogiri"
require "securerandom"
require_relative "./patient_parser"
require_relative "./encounter_parser"
require_relative "./medication_parser"
require_relative "./assessment_parser"
require_relative "./intervention_order_parser"
require_relative "./intervention_performed_parser"
require_relative "./procedure_performed_parser"
require_relative "./diagnosis_parser"
# frozen_string_literal: true
# QrdaParser is responsible for parsing QRDA documents and extracting relevant information.

class QrdaParser
  attr_reader :doc, :ns

  def initialize(file)
    @doc = Nokogiri::XML(file)
    @ns = { "hl7" => "urn:hl7-org:v3", "sdtc" => "urn:hl7-org:sdtc" }
  end

  def extract_patient
    PatientParser.extract_patient(doc, ns)
  end

  def extract_encounter
    EncounterParser.extract_encounter(doc, ns)
  end

  def extract_encounters
    EncounterParser.extract_encounters(doc, ns)
  end

  def extract_medication
    MedicationParser.extract_medication(doc, ns)
  end

  def extract_medications
    MedicationParser.extract_medications(doc, ns)
  end

  def extract_assessment
    AssessmentParser.extract_assessment(doc, ns)
  end

  def extract_assessments
    AssessmentParser.extract_assessments(doc, ns)
  end

  def extract_intervention_order
    InterventionOrderParser.extract_order(doc, ns)
  end

  def extract_intervention_orders
    InterventionOrderParser.extract_orders(doc, ns)
  end

  def extract_intervention_performed
    InterventionPerformedParser.extract_one(doc, ns)
  end

  def extract_intervention_performeds
    InterventionPerformedParser.extract_performed(doc, ns)
  end

  def extract_procedure_performed
    ProcedurePerformedParser.extract_performed(doc, ns)
  end

  def extract_procedure_performeds
    ProcedurePerformedParser.extract_performeds(doc, ns)
  end

  def extract_diagnoses
    DiagnosisParser.extract_diagnoses(doc, ns)
  end
end
