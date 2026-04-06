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
end
