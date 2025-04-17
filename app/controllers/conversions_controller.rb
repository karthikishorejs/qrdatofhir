require "zip"

class ConversionsController < ApplicationController
  def create
    uploaded_file = params[:file]
    Dir.mktmpdir do |dir|
      process_zip_file(uploaded_file, dir)
    end

    render json: { status: "success" }
  end

  private

  def process_zip_file(uploaded_file, dir)
    Zip::File.open(uploaded_file.path) do |zip_file|
      zip_file.each do |entry|
        next unless entry.name.end_with?(".xml")
        process_xml_entry(entry, dir)
      end
    end
  end

  def process_xml_entry(entry, dir)
    extracted = extract_file(entry, dir)
    parser = QrdaParser.new(File.read(extracted))

    # Extract patient and encounter data
    patient_data = parser.extract_patient
    encounter_data = parser.extract_encounter

    # Build FHIR resources
    patient = FhirBundleBuilder.build_patient(patient_data)
    encounter = encounter_data ? FhirBundleBuilder.build_encounter(encounter_data, patient.id) : nil
    medication = FhirBundleBuilder.build_medication(patient_data[:id])

    # Write the output files
    write_output_files(entry, patient, encounter, medication)
  end

  def extract_file(entry, dir)
    extracted = File.join(dir, entry.name)
    entry.extract(extracted)
    extracted
  end

  def write_output_files(entry, patient, encounter, medication)
    base = File.basename(entry.name, ".xml")
    output_dir = Rails.root.join("output", base)
    FileUtils.mkdir_p(output_dir)

    File.write(output_dir.join("patient_#{patient.id}.json"), patient.to_json)
    if encounter
      File.write(output_dir.join("encounter_#{encounter.id}.json"), encounter.to_json)
    end
    if medication
      File.write(output_dir.join("medication_#{medication.id}.json"), medication.to_json)
    end
  end
end
