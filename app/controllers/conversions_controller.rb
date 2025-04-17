require 'zip'

class ConversionsController < ApplicationController

  def create
    uploaded_file = params[:file]
    Dir.mktmpdir do |dir|
      process_zip_file(uploaded_file, dir)
    end

    render json: { status: 'success' }
  end

  private

  def process_zip_file(uploaded_file, dir)
    Zip::File.open(uploaded_file.path) do |zip_file|
      zip_file.each do |entry|
        next unless entry.name.end_with?('.xml')
        process_xml_entry(entry, dir)
      end
    end
  end

  def process_xml_entry(entry, dir)
    extracted = extract_file(entry, dir)
    patient_data = parse_patient_data(extracted)

    patient = FhirBundleBuilder.build_patient(patient_data)
    encounter = FhirBundleBuilder.build_encounter(patient_data[:id])
    medication = FhirBundleBuilder.build_medication(patient_data[:id])

    write_output_files(entry, patient, encounter, medication)
  end

  def extract_file(entry, dir)
    extracted = File.join(dir, entry.name)
    entry.extract(extracted)
    extracted
  end

  def parse_patient_data(file_path)
    parser = QrdaParser.new(File.read(file_path))
    parser.extract_patient
  end

  def write_output_files(entry, patient, encounter, medication)
    base = File.basename(entry.name, ".xml")
    output_dir = Rails.root.join("output", base)
    FileUtils.mkdir_p(output_dir)

    File.write(output_dir.join("patient_#{patient.id}.json"), patient.to_json)
    File.write(output_dir.join("encounter.json"), encounter.to_json)
    File.write(output_dir.join("medication.json"), medication.to_json)
  end
end
