require 'rails_helper'
require_relative "../../../app/services/qrda/qrda_parser"

RSpec.describe QrdaParser, type: :service do
  let(:xml_file) { File.read(Rails.root.join('spec/fixtures/qrda_sample.xml')) }
  let(:parser) { described_class.new(xml_file) }
  let(:patient_data) { parser.extract_patient }

  it "extracts patient id" do
    expect(patient_data[:id]).to eq("12345")
  end

  it "extracts birth date" do
    expect(patient_data[:birth_date]).to eq('19910302190000')
  end

  it "extracts gender" do
    expect(patient_data[:gender]).to eq('f')
  end

  it "extracts name" do
    expect(patient_data[:name][:given]).to eq('Age17InEDAge18DayOfIPAdmit')
    expect(patient_data[:name][:family]).to eq('DENOMPass')
  end

  it "extracts race" do
    expect(patient_data[:race][:code]).to eq('1002-5')
    expect(patient_data[:race][:system]).to eq('2.16.840.1.113883.6.238')
  end

  it "extracts ethnicity" do
    expect(patient_data[:ethnicity][:code]).to eq('2135-2')
    expect(patient_data[:ethnicity][:system]).to eq('2.16.840.1.113883.6.238')
  end
end
