require "rails_helper"

RSpec.describe ConversionsController, type: :controller do
  before do
    @routes = Rails.application.routes
  end

  describe "POST #create" do
    subject(:make_request) { post :create, params: { file: uploaded_file } }

    let(:uploaded_file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/valid_qrda.zip"),
        "application/zip"
      )
    end
    let(:temp_dir) { "/tmp/qrda-upload" }

    before do
      allow(Dir).to receive(:mktmpdir).and_yield(temp_dir)
      allow(controller).to receive(:process_zip_file)
    end

    context "when verifying request orchestration" do
      after do
        make_request
      end

      it "creates a temp directory for the upload" do
        expect(Dir).to receive(:mktmpdir).and_yield(temp_dir)
      end

      it "passes the uploaded zip file to the processor" do
        expect(controller).to receive(:process_zip_file).with(
          satisfy do |file|
            file.is_a?(ActionDispatch::Http::UploadedFile) &&
              file.original_filename == "valid_qrda.zip" &&
              File.extname(file.path) == ".zip"
          end,
          temp_dir
        )
      end
    end

    context "after the request is processed" do
      before do
        make_request
      end

      it "returns a successful response" do
        expect(response).to have_http_status(:success)
      end

      it "returns a success payload" do
        expect(JSON.parse(response.body)).to eq("status" => "success")
      end
    end
  end

  describe "#process_zip_file" do
    subject(:process_zip_file) { controller.send(:process_zip_file, uploaded_file, working_dir) }

    let(:uploaded_file) { instance_double(ActionDispatch::Http::UploadedFile, path: "/tmp/upload.zip") }
    let(:xml_entry) { instance_double(Zip::Entry, name: "patient.xml") }
    let(:non_xml_entry) { instance_double(Zip::Entry, name: "notes.txt") }
    let(:zip_file) { instance_double(Zip::File) }
    let(:working_dir) { "/tmp/work" }

    before do
      # Call the block twice, first with valid xml then with non-xml.
      allow(zip_file).to receive(:each).and_yield(xml_entry).and_yield(non_xml_entry)

      allow(Zip::File).to receive(:open).and_yield(zip_file)
      allow(controller).to receive(:process_xml_entry)
    end

    after do
      process_zip_file
    end

    it "opens the uploaded zip archive" do
      expect(Zip::File).to receive(:open).with("/tmp/upload.zip").and_yield(zip_file)
    end

    it "processes xml entries" do
      expect(controller).to receive(:process_xml_entry).with(xml_entry, working_dir)
    end

    it "skips non-xml entries" do
      expect(controller).not_to receive(:process_xml_entry).with(non_xml_entry, anything)
    end
  end

  describe "#process_xml_entry" do
    subject(:process_xml_entry) { controller.send(:process_xml_entry, entry, working_dir) }

    let(:entry) { instance_double(Zip::Entry, name: "sample.xml") }
    let(:parser) { instance_double(QrdaParser) }
    let(:patient_data) { { "id" => "patient-1" } }
    let(:encounter_data) { { "id" => "encounter-1" } }
    let(:medication_data) { { "id" => "medication-1" } }
    let(:patient) { instance_double("FHIR::Patient", id: "patient-1") }
    let(:encounter) { instance_double("FHIR::Encounter", id: "encounter-1") }
    let(:medication) { instance_double("FHIR::MedicationRequest", id: "medication-1") }
    let(:working_dir) { "/tmp/work" }

    before do
      allow(controller).to receive(:extract_file).with(entry, working_dir).and_return("/tmp/work/sample.xml")
      allow(File).to receive(:read).with("/tmp/work/sample.xml").and_return("<ClinicalDocument />")
      allow(QrdaParser).to receive(:new).with("<ClinicalDocument />").and_return(parser)
      allow(parser).to receive(:extract_patient).and_return(patient_data)
      allow(parser).to receive(:extract_encounter).and_return(encounter_data)
      allow(parser).to receive(:extract_medication).and_return(medication_data)
      allow(FhirBundleBuilder).to receive(:build_patient).with(patient_data).and_return(patient)
      allow(FhirBundleBuilder).to receive(:build_encounter).with(encounter_data, "patient-1").and_return(encounter)
      allow(FhirBundleBuilder).to receive(:build_medication).with(medication_data, "patient-1").and_return(medication)
      allow(controller).to receive(:write_output_files)
    end

    after do
      process_xml_entry
    end

    it "writes the built resources to output files" do
      expect(controller).to receive(:write_output_files).with(entry, patient, encounter, medication)
    end

    context "when encounter and medication data are absent" do
      before do
        allow(parser).to receive(:extract_encounter).and_return(nil)
        allow(parser).to receive(:extract_medication).and_return(nil)
      end

      it "does not build an encounter resource" do
        expect(FhirBundleBuilder).not_to receive(:build_encounter)
      end

      it "does not build a medication resource" do
        expect(FhirBundleBuilder).not_to receive(:build_medication)
      end

      it "writes output with only the patient resource" do
        expect(controller).to receive(:write_output_files).with(entry, patient, nil, nil)
      end
    end
  end

  describe "#extract_file" do
    subject(:extract_file) { controller.send(:extract_file, entry, working_dir) }

    let(:entry) { instance_double(Zip::Entry, name: "nested/sample.xml") }
    let(:expected_path) { File.join(working_dir, "nested/sample.xml") }
    let(:working_dir) { "/tmp/work" }

    before do
      allow(entry).to receive(:extract)
    end

    after do
      extract_file
    end

    it "extracts the entry into the provided directory" do
      expect(entry).to receive(:extract).with(expected_path)
    end

    it "returns the extracted file path" do
      expect(extract_file).to eq(expected_path)
    end
  end

  describe "#write_output_files" do
    subject(:write_output_files) { controller.send(:write_output_files, entry, patient, encounter, medication) }

    let(:entry) { instance_double(Zip::Entry, name: "sample.xml") }
    let(:output_dir) { Rails.root.join("output", "sample") }
    let(:patient) { instance_double("FHIR::Patient", id: "patient-1", to_json: '{"resource":"Patient"}') }
    let(:encounter) { instance_double("FHIR::Encounter", id: "encounter-1", to_json: '{"resource":"Encounter"}') }
    let(:medication) { instance_double("FHIR::MedicationRequest", id: "medication-1", to_json: '{"resource":"MedicationRequest"}') }

    before do
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:write)
    end

    after do
      write_output_files
    end

    it "creates the output directory" do
      expect(FileUtils).to receive(:mkdir_p).with(output_dir)
    end

    it "writes the patient json file" do
      expect(File).to receive(:write).with(output_dir.join("patient_patient-1.json"), '{"resource":"Patient"}')
    end

    it "writes the encounter json file" do
      expect(File).to receive(:write).with(output_dir.join("encounter_encounter-1.json"), '{"resource":"Encounter"}')
    end

    it "writes the medication json file" do
      expect(File).to receive(:write).with(output_dir.join("medication_medication-1.json"), '{"resource":"MedicationRequest"}')
    end

    context "when optional resources are absent" do
      let(:encounter) { nil }
      let(:medication) { nil }

      it "still creates the output directory" do
        expect(FileUtils).to receive(:mkdir_p).with(output_dir)
      end

      it "still writes the patient json file" do
        expect(File).to receive(:write).with(output_dir.join("patient_patient-1.json"), '{"resource":"Patient"}')
      end

      it "does not write an encounter json file" do
        expect(File).not_to receive(:write).with(output_dir.join("encounter_encounter-1.json"), anything)
      end

      it "does not write a medication json file" do
        expect(File).not_to receive(:write).with(output_dir.join("medication_medication-1.json"), anything)
      end
    end
  end
end
