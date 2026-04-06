# frozen_string_literal: true

#
# Central helper for producing FHIR R4 compliant ids.
#
# FHIR R4 id regex: [A-Za-z0-9\-\.]{1,64}
# - Underscore '_' is not allowed.
# - Length max is 64.
#
# QRDA source ids often contain underscores and other characters that are not FHIR compliant.
#
module FhirIdHelper
  FHIR_ID_MAX_LENGTH = 64
  FHIR_ID_ALLOWED = /[^A-Za-z0-9\-\.]/.freeze

  def self.fhir_id(raw)
    return nil if raw.nil?

    id = raw.to_s.strip
    return nil if id.empty?

    id = id.tr("_", "-")
    id = id.gsub(FHIR_ID_ALLOWED, "-")
    id = id[0, FHIR_ID_MAX_LENGTH]
    id
  end
end
