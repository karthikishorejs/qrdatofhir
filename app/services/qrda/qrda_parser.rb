require "nokogiri"
require "securerandom"
require_relative "./patient_parser"
require_relative "./encounter_parser"
require_relative "./medication_parser"
# frozen_string_literal: true
# QrdaParser is responsible for parsing QRDA documents and extracting relevant information.

class QrdaParser
  attr_reader :doc, :ns

  def initialize(file)
    @doc = Nokogiri::XML(file)
    @ns = { "hl7" => "urn:hl7-org:v3" }
  end

  def extract_patient
    PatientParser.extract_patient(doc, ns)
  end

  def extract_encounter
    EncounterParser.extract_encounter(doc, ns)
  end

  def extract_medication
    MedicationParser.extract_medication(doc, ns)
  end
end
