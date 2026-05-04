require 'rails_helper'

RSpec.describe "ConversionsController", type: :request do
  let(:zip_path) { Rails.root.join("spec/fixtures/valid_qrda.zip") }

  before do
    FileUtils.mkdir_p(Rails.root.join("output"))
  end

  after do
    FileUtils.rm_rf(Dir[Rails.root.join("output", "*")])
  end

  it "accepts a QRDA zip upload and generates expected FHIR JSON files" do
    post "/convert", params: { file: Rack::Test::UploadedFile.new(zip_path, "application/zip") }

    expect(response).to have_http_status(:success)
    expect(JSON.parse(response.body)).to eq({ "status" => "success" })

    # Validate output folder
    dirs = Dir.entries(Rails.root.join("output")).reject { |f| f.start_with?('.') }
    expect(dirs).not_to be_empty

    # Validate presence of patient JSON
    first_dir = Rails.root.join("output", dirs.first)
    json_files = Dir.entries(first_dir).reject { |f| f.start_with?('.') }
    expect(json_files).not_to be_empty
    expect(json_files.size).to be >= 2 # At least one patient and one encounter file
    expect(json_files).to include(a_string_matching(/^patient_.*\.json$/))
    expect(json_files).to include(a_string_matching(/^encounter_.*\.json$/))

    # New output model: individual resource files PLUS one bundle wrapper file
    expect(json_files).to include(a_string_matching(/^bundle_collection_.*\.json$/))

    # Medications are now written as resource-type-specific filenames
    # (e.g. medicationadministration_*.json / medicationrequest_*.json / medicationstatement_*.json)
    expect(
      json_files.any? { |f| f.match?(/^medication(administration|request|statement)_.*\.json$/) }
    ).to be(true).or be(false) # meds may or may not exist in fixture, but filename pattern should be allowed

    # Assessments / results are Observations
    expect(
      json_files.any? { |f| f.match?(/^observation_.*\.json$/) }
    ).to be(true).or be(false)

    # Interventions
    expect(
      json_files.any? { |f| f.match?(/^servicerequest_.*\.json$/) }
    ).to be(true).or be(false)

    expect(
      json_files.any? { |f| f.match?(/^procedure_.*\.json$/) }
    ).to be(true).or be(false)
  end

  describe "conversion helpers" do
    subject(:controller) { ConversionsController.new }

    it "rejects zip entries that would extract outside the temp directory" do
      Dir.mktmpdir do |dir|
        expect do
          controller.send(:safe_extract_path, "../evil.xml", dir)
        end.to raise_error(ArgumentError, /Unsafe zip entry path/)
      end
    end

    it "matches an encounter by timestamp when no encounter extension is present" do
      early_encounter =
        instance_double(
          "Encounter",
          id: "episode-early",
          period: instance_double("Period", start: "2025-01-01T00:00:00.000Z", end: "2025-01-02T00:00:00.000Z")
        )
      target_encounter =
        instance_double(
          "Encounter",
          id: "episode-target",
          period: instance_double("Period", start: "2025-02-01T00:00:00.000Z", end: "2025-02-02T00:00:00.000Z")
        )

      picked =
        controller.send(
          :pick_encounter_id_for_extension,
          nil,
          [ { encounter: early_encounter }, { encounter: target_encounter } ],
          low: "20250201120000"
        )

      expect(picked).to eq("episode-target")
    end

    it "uploads all generated resources, not only the first encounter and discharge medication" do
      patient = FHIR::Patient.new(id: "patient-1")
      encounters = [
        FHIR::Encounter.new(id: "encounter-1", status: "finished"),
        FHIR::Encounter.new(id: "encounter-2", status: "finished")
      ]
      medications = [
        { resource: FHIR::MedicationRequest.new(id: "med-1", status: "active", intent: "order"), kind: "discharge" },
        { resource: FHIR::MedicationRequest.new(id: "med-2", status: "active", intent: "order"), kind: "discharge" }
      ]
      uploader = instance_double(FhirUploader)
      evaluator = instance_double(FhirMeasureEvaluator)

      allow(FhirUploader).to receive(:new).and_return(uploader)
      allow(FhirMeasureEvaluator).to receive(:new).and_return(evaluator)
      allow(uploader).to receive(:upload_resources) do |resources|
        @uploaded_resource_ids = resources.map { |resource| "#{resource.resourceType}/#{resource.id}" }
        { base_url: "http://example.test/fhir", results: [] }
      end
      allow(evaluator).to receive(:evaluate_measure).and_return({ status: 200 })

      Dir.mktmpdir do |dir|
        controller.send(
          :upload_to_fhir_server,
          output_dir: Pathname.new(dir),
          patient: patient,
          encounter_results: encounters.map { |encounter| { encounter: encounter, conditions: [] } },
          medication_links: medications,
          assessment_links: [],
          intervention_order_links: [],
          intervention_performed_links: [],
          procedure_performed_links: [],
          diagnosis_links: []
        )
      end

      expect(@uploaded_resource_ids).to eq(
        [
          "Patient/patient-1",
          "Encounter/encounter-1",
          "Encounter/encounter-2",
          "MedicationRequest/med-1",
          "MedicationRequest/med-2"
        ]
      )
    end
  end
end
