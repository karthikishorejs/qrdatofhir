require "fhir_models"
require "securerandom"

# BundleBuilder builds a single FHIR Bundle that groups related resources.
# Used to emit one JSON file per encounter_id containing Patient + Encounter + related resources.
class BundleBuilder
  def self.build_bundle(patient:, encounter:, conditions: [], medications: [])
    entries = []
    add(entries, patient)
    add(entries, encounter)
    Array(conditions).each { |c| add(entries, c) }
    Array(medications).each { |m| add(entries, m) }

    FHIR::Bundle.new(
      id: SecureRandom.uuid,
      type: "collection",
      entry: entries
    )
  end

  def self.add(entries, resource)
    return if resource.nil?

    entries << FHIR::Bundle::Entry.new(
      # Use REST-style fullUrl so internal references like "Patient/<id>" remain consistent.
      fullUrl: "#{resource.resourceType}/#{resource.id}",
      resource: resource
    )
  end
end
