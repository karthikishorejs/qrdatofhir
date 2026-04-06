# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

# Uploads FHIR resources to a FHIR R4 server using PUT /{ResourceType}/{id}
# and captures responses for auditing/debugging.
class FhirUploader
  DEFAULT_HEADERS = {
    "Content-Type" => "application/fhir+json",
    "Accept" => "application/fhir+json",
    # Avoid the "Expect: 100-continue" behavior some servers/clients trigger.
    "Expect" => ""
  }.freeze

  def initialize(base_url:)
    @base_url = base_url.to_s.sub(%r{/\z}, "")
    @base_uri = URI.parse(@base_url)
  end

  # resources: array of FHIR::Model instances (from fhir_models) OR Ruby hashes (FHIR JSON)
  # returns: { base_url:, results: [ ... ] }
  def upload_resources(resources)
    results = []

    Array(resources).each do |resource|
      next unless resource

      json = resource.is_a?(String) ? resource : resource.to_json
      parsed = JSON.parse(json) rescue nil

      resource_type =
        if parsed.is_a?(Hash)
          parsed["resourceType"]
        elsif resource.respond_to?(:resourceType)
          resource.resourceType
        end

      id =
        if parsed.is_a?(Hash)
          parsed["id"]
        else
          resource.respond_to?(:id) ? resource.id : nil
        end

      unless resource_type && !resource_type.to_s.empty? && id && !id.to_s.empty?
        results << {
          ok: false,
          error: "Missing resourceType and/or id; cannot PUT",
          resourceType: resource_type,
          id: id
        }
        next
      end

      path = "#{@base_uri.path}".sub(%r{/\z}, "")
      path = "" if path == "/"
      full_path = "#{path}/#{resource_type}/#{id}"
      uri = @base_uri.dup
      uri.path = full_path

      res = put(uri, json)

      results << {
        ok: res.is_a?(Net::HTTPSuccess),
        resourceType: resource_type,
        id: id,
        url: uri.to_s,
        status: res.code.to_i,
        response_headers: res.to_hash,
        response_body: safe_body(res)
      }
    rescue StandardError => e
      results << {
        ok: false,
        resourceType: resource_type,
        id: id,
        url: (uri&.to_s),
        error: "#{e.class}: #{e.message}"
      }
    end

    { base_url: @base_url, results: results }
  end

  private

  def put(uri, body)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.read_timeout = 120
    http.open_timeout = 10

    req = Net::HTTP::Put.new(uri.request_uri)
    DEFAULT_HEADERS.each { |k, v| req[k] = v }
    req.body = body

    http.request(req)
  end

  def safe_body(res)
    b = res.body.to_s
    return b if b.bytesize <= 200_000

    b.byteslice(0, 200_000) + "\n...truncated..."
  end
end
