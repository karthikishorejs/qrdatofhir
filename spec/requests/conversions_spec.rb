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
    expect(json_files).to include(a_string_matching(/^patient_.*\.json$/))
    expect(json_files).to include("encounter.json", "medication.json")
  end
end
