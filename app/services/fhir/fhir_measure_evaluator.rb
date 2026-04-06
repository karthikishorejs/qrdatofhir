# frozen_string_literal: true
require "net/http"
require "uri"
require "json"

# Calls $evaluate-measure on a FHIR server.
class FhirMeasureEvaluator
  def initialize(base_url:)
    @base_url = base_url.to_s.sub(%r{/\z}, "")
    @base_uri = URI.parse(@base_url)
  end

  # Returns: { url:, status:, headers:, body: }
  def evaluate_measure(measure_id:, subject_ref:, period_start:, period_end:)
    path = "#{@base_uri.path}".sub(%r{/\z}, "")
    path = "" if path == "/"

    uri = @base_uri.dup
    uri.path = "#{path}/Measure/#{measure_id}/$evaluate-measure"
    uri.query = URI.encode_www_form(
      {
        "subject" => subject_ref,
        "periodStart" => period_start,
        "periodEnd" => period_end
      }
    )

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.read_timeout = 300
    http.open_timeout = 10

    req = Net::HTTP::Get.new(uri.request_uri)
    req["Accept"] = "application/fhir+json"

    res = http.request(req)
    {
      url: uri.to_s,
      status: res.code.to_i,
      headers: res.to_hash,
      body: safe_body(res)
    }
  end

  private

  def safe_body(res)
    b = res.body.to_s
    return b if b.bytesize <= 500_000

    b.byteslice(0, 500_000) + "\n...truncated..."
  end
end
