require 'rails_helper'

RSpec.describe "ConversionsController", type: :request do
  subject(:make_request) do
    post "/convert", params: { file: Rack::Test::UploadedFile.new(zip_path, "application/zip") }
  end

  let(:zip_path) { Rails.root.join("spec/fixtures/valid_qrda.zip") }
  let(:output_root) { Rails.root.join("output") }
  let(:output_dirs) { Dir.entries(output_root).reject { |file| file.start_with?(".") } }
  let(:first_output_dir) { output_root.join(output_dirs.fetch(0)) }
  let(:json_files) { Dir.entries(first_output_dir).reject { |file| file.start_with?(".") } }

  before do
    FileUtils.mkdir_p(output_root)
  end

  after do
    FileUtils.rm_rf(Dir[output_root.join("*")])
  end

  context "after uploading a valid QRDA zip" do
    before do
      make_request
    end

    it "returns a successful response" do
      expect(response).to have_http_status(:success)
    end

    it "returns a success payload" do
      expect(JSON.parse(response.body)).to eq("status" => "success")
    end

    it "creates an output directory" do
      expect(output_dirs).not_to be_empty
    end

    it "creates json output files" do
      expect(json_files).not_to be_empty
    end

    it "creates a patient json file" do
      expect(json_files).to include(a_string_matching(/^patient_.*\.json$/))
    end

    it "creates an encounter json file" do
      expect(json_files).to include(a_string_matching(/^encounter_.*\.json$/))
    end

    it "does not create a medication json file" do
      expect(json_files).not_to include(a_string_matching(/^medication_.*\.json$/))
    end
  end
end
