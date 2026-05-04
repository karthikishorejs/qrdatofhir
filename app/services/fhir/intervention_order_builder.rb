require "fhir_models"
require "securerandom"
require "time"
require_relative "../../constants/fhir_constants"

# InterventionOrderBuilder builds FHIR ServiceRequest resources for QRDA "Intervention, Order".
#
# QRDA Template: 2.16.840.1.113883.10.20.24.3.31 (act moodCode="RQO")
#
# Mapping (best-effort):
# - ServiceRequest.status: from QRDA statusCode / negationInd
# - ServiceRequest.intent: "order"
# - ServiceRequest.code: from QRDA act/code
# - ServiceRequest.subject: Patient
# - ServiceRequest.encounter: linked by controller using extension join logic
# - ServiceRequest.authoredOn: from effectiveTime low/value
# - ServiceRequest.occurrence[x]: retained from effectiveTime low/high/value
# - negationInd: mapped to doNotPerform=true (common FHIR pattern for "not ordered/performed")
class InterventionOrderBuilder
  def self.build_service_request(order_data, patient_id, encounter_id: nil)
    sr = FHIR::ServiceRequest.new(
      id: order_data[:order_id] || SecureRandom.uuid,
      status: map_status(order_data),
      intent: "order",
      subject: FHIR::Reference.new(reference: "Patient/#{patient_id}"),
      code: build_codeable_concept(order_data[:code]),
      doNotPerform: order_data[:negation_ind] ? true : nil,
      authoredOn: nil,
      occurrenceDateTime: nil,
      occurrencePeriod: nil,
      meta: { profile: [ FHIRConstants::QICORE_SERVICE_REQUEST_PROFILE ] }
    )

    apply_order_timing(sr, order_data[:effective_low], order_data[:effective_high])
    sr.encounter = FHIR::Reference.new(reference: "Encounter/#{encounter_id}") if encounter_id

    sr
  end

  private

  def self.map_status(order_data)
    return "revoked" if order_data[:negation_ind]

    code = order_data[:status_code].to_s.strip.downcase
    return "active" if code.empty? || code == "active"
    return "completed" if code == "completed"
    return "on-hold" if code == "suspended"

    "unknown"
  end

  def self.build_codeable_concept(code_hash)
    return nil if code_hash.nil? || code_hash[:code].to_s.strip.empty?

    FHIR::CodeableConcept.new(
      coding: [
        FHIR::Coding.new(
          system: map_code_system(code_hash[:code_system]),
          code: code_hash[:code],
          display: code_hash[:display] || code_hash[:code_system_name]
        )
      ]
    )
  end

  def self.map_code_system(code_system)
    FHIRConstants::CODE_SYSTEM_MAPPINGS[code_system] || code_system
  end

  def self.apply_order_timing(sr, low, high)
    start_t = parse_time(low)
    end_t = parse_time(high)

    sr.authoredOn = start_t.iso8601(3) if start_t

    if start_t && end_t
      sr.occurrencePeriod = FHIR::Period.new(
        start: start_t.iso8601(3),
        end: end_t.iso8601(3)
      )
    elsif start_t
      sr.occurrenceDateTime = start_t.iso8601(3)
    end
  end

  def self.parse_time(value)
    return nil if value.nil?

    v = value.to_s.strip
    return nil if v.empty?

    t =
      if v.match?(/^\d{14}[+-]\d{4}$/)
        Time.strptime(v, "%Y%m%d%H%M%S%z")
      elsif v.match?(/^\d{14}Z$/)
        Time.strptime(v, "%Y%m%d%H%M%SZ")
      elsif v.match?(/^\d{14}$/)
        Time.strptime(v, "%Y%m%d%H%M%S").utc
      elsif v.match?(/^\d{8}$/)
        Time.strptime(v, "%Y%m%d").utc
      else
        Time.parse(v).utc
      end

    t.utc
  rescue StandardError
    nil
  end

  private_class_method :map_status, :build_codeable_concept, :map_code_system, :apply_order_timing, :parse_time
end
