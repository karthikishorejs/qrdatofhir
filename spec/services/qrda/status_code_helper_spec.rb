require_relative "../../../app/services/qrda/status_code_helper"

RSpec.describe StatusCodeHelper do
  let(:dummy_class) { Class.new { extend StatusCodeHelper } }

  describe "#extract_encounter_status_code" do
    it "returns 'finished' for 'completed'" do
      expect(dummy_class.extract_status_code("completed")).to eq("finished")
    end

    it "returns 'in-progress' for 'in-progress'" do
      expect(dummy_class.extract_status_code("in-progress")).to eq("in-progress")
    end

    it "returns 'unknown' for an unrecognized status code" do
      expect(dummy_class.extract_status_code("unknown-status")).to eq("unknown")
    end

    it "returns 'unknown' if the status code is nil" do
      expect(dummy_class.extract_status_code(nil)).to eq("unknown")
    end
  end
end
