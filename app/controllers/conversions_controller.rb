require "zip"
require "json"
require_relative "../services/qrda/qrda_parser"
require_relative "../services/fhir/fhir_bundle_builder"
require_relative "../services/fhir/bundle_builder"
require_relative "../services/fhir/fhir_uploader"
require_relative "../services/fhir/fhir_measure_evaluator"
require_relative "../constants/fhir_constants"

class ConversionsController < ApplicationController
  def create
    uploaded_file = params[:file]
    Dir.mktmpdir do |dir|
      process_zip_file(uploaded_file, dir)
    end

    render json: { status: "success" }
  end

  private

  def process_zip_file(uploaded_file, dir)
    Zip::File.open(uploaded_file.path) do |zip_file|
      zip_file.each do |entry|
        next unless entry.name.end_with?(".xml")
        process_xml_entry(entry, dir)
      end
    end
  end

  def process_xml_entry(entry, dir)
    extracted = extract_file(entry, dir)
    parser = QrdaParser.new(File.read(extracted))

    # Extract QRDA data
    patient_data = parser.extract_patient
    encounters_data = parser.extract_encounters
    medications_data = parser.extract_medications
    assessments_data = parser.extract_assessments
    intervention_orders_data = parser.extract_intervention_orders
    intervention_performeds_data = parser.extract_intervention_performeds
    procedure_performeds_data = parser.extract_procedure_performeds
    diagnoses_data = parser.extract_diagnoses

    # Build FHIR resources (1 QRDA entry => 1 FHIR resource)
    patient = FhirBundleBuilder.build_patient(patient_data)

    encounter_results = encounters_data.map do |enc_data|
      encounter = FhirBundleBuilder.build_encounter(enc_data, patient.id)

      # Capture conditions produced while building this specific encounter.
      conditions = EncounterBuilder.last_conditions

      { encounter: encounter, conditions: conditions }
    end

    # Build medications and associate to an Encounter segment (if resolvable)
    medication_links = medications_data.map do |m|
      encounter_id = pick_encounter_id_for_medication(m, encounter_results)
      med_resource = FhirBundleBuilder.build_medication(m, patient.id, encounter_id: encounter_id)
      { resource: med_resource, encounter_id: encounter_id, kind: m[:kind] }
    end

    # Build assessment observations and associate to an Encounter segment (if resolvable)
    assessment_links = assessments_data.map do |a|
      encounter_id =
        pick_encounter_id_for_extension(
          a[:encounter_extension],
          encounter_results,
          low: a[:effective_low],
          high: a[:effective_high]
        )

      obs_resource = FhirBundleBuilder.build_assessment(a, patient.id, encounter_id: encounter_id)
      { resource: obs_resource, encounter_id: encounter_id }
    end

    intervention_order_links = intervention_orders_data.map do |io|
      encounter_id =
        pick_encounter_id_for_extension(
          io[:encounter_extension],
          encounter_results,
          low: io[:effective_low],
          high: io[:effective_high]
        )

      sr_resource = FhirBundleBuilder.build_intervention_order(io, patient.id, encounter_id: encounter_id)
      { resource: sr_resource, encounter_id: encounter_id }
    end

    intervention_performed_links = intervention_performeds_data.map do |ip|
      encounter_id =
        pick_encounter_id_for_extension(
          ip[:encounter_extension],
          encounter_results,
          low: ip[:effective_low],
          high: ip[:effective_high]
        )

      proc_resource = FhirBundleBuilder.build_intervention_performed(ip, patient.id, encounter_id: encounter_id)

      linked = [ { resource: proc_resource, encounter_id: encounter_id } ]

      # If QRDA contains an embedded result observation, emit it as a separate Observation resource file too.
      if ip[:result]
        obs_id = "#{proc_resource.id}-result"
        result_obs = AssessmentBuilder.build_observation(
          {
            assessment_id: obs_id,
            negation_ind: false,
            status_code: "completed",
            effective_low: ip[:result][:effective_low],
            effective_high: ip[:result][:effective_high],
            code: ip[:result][:code],
            value: ip[:result][:value]
          },
          patient.id,
          encounter_id: encounter_id
        )
        linked << { resource: result_obs, encounter_id: encounter_id }
      end

      linked
    end.flatten

    diagnosis_links = diagnoses_data.map do |d|
      encounter_id =
        pick_encounter_id_for_extension(
          d[:encounter_extension],
          encounter_results,
          low: d[:effective_low],
          high: d[:effective_high]
        )

      condition = ConditionBuilder.build_condition(
        {
          diagnosis_id: d[:diagnosis_id],
          diagnosis: d[:diagnosis],
          poa: d[:poa]
        },
        patient.id,
        encounter_id: encounter_id
      )
      { resource: condition, encounter_id: encounter_id }
    end

    procedure_performed_links = procedure_performeds_data.map do |pp|
      encounter_id =
        pick_encounter_id_for_extension(
          pp[:encounter_extension],
          encounter_results,
          low: pp[:effective_low],
          high: pp[:effective_high]
        )

      proc_resource = FhirBundleBuilder.build_procedure_performed(pp, patient.id, encounter_id: encounter_id)
      { resource: proc_resource, encounter_id: encounter_id }
    end

    output_dir = write_resources_and_bundle(
      entry,
      patient,
      encounter_results,
      medication_links,
      assessment_links,
      intervention_order_links,
      intervention_performed_links,
      procedure_performed_links,
      diagnosis_links
    )

    upload_results =
      begin
        upload_to_fhir_server(
          output_dir: output_dir,
          patient: patient,
          encounter_results: encounter_results,
          medication_links: medication_links,
          assessment_links: assessment_links,
          intervention_order_links: intervention_order_links,
          intervention_performed_links: intervention_performed_links,
          procedure_performed_links: procedure_performed_links,
          diagnosis_links: diagnosis_links
        )
      rescue StandardError => e
        {
          base_url: ENV.fetch("FHIR_BASE_URL", "http://127.0.0.1:8080/fhir"),
          ok: false,
          error: {
            exception: e.class.to_s,
            message: e.message.to_s,
            backtrace: Array(e.backtrace).first(30)
          }
        }
      end

    json_out =
      JSON.pretty_generate(upload_results).encode(
        "UTF-8",
        invalid: :replace,
        undef: :replace,
        replace: ""
      )

    File.write(output_dir.join("fhir_upload_result.json"), json_out)
  end

  def extract_file(entry, dir)
    extracted = File.join(dir, entry.name)
    entry.extract(extracted)
    extracted
  end

  def pick_encounter_id_for_medication(med_hash, encounter_results)
    pick_encounter_id_for_extension(
      med_hash[:encounter_id],
      encounter_results,
      low: med_hash[:low_time],
      high: med_hash[:high_time]
    )
  end

  def parse_time(value)
    return nil if value.nil?

    v = value.to_s.strip
    return nil if v.empty?

    # EncounterBuilder/Medication builders output ISO8601, QRDA provides YYYYMMDD... strings.
    Time.parse(v).utc
  rescue StandardError
    nil
  end

  def pick_encounter_id_for_extension(extension, encounter_results, low: nil, high: nil)
    ext = extension.to_s.strip
    return nil if ext.empty?

    candidates =
      Array(encounter_results).map { |r| r[:encounter] }.compact.select do |enc|
        enc.id.to_s.start_with?("#{ext}-") || enc.id.to_s == ext
      end

    return candidates.first&.id if candidates.length <= 1

    # If multiple encounter segments share the same extension, choose the one whose period covers
    # the template timestamp (best-effort).
    template_time = parse_time(low || high)
    return candidates.first&.id unless template_time

    candidates.each do |enc|
      start_t = parse_time(enc.period&.start)
      end_t = parse_time(enc.period&.end)
      next unless start_t && end_t
      return enc.id if (start_t..end_t).cover?(template_time)
    end

    candidates.first&.id
  rescue StandardError
    candidates&.first&.id
  end

  def write_resources_and_bundle(
    entry,
    patient,
    encounter_results,
    medication_links,
    assessment_links,
    intervention_order_links = [],
    intervention_performed_links = [],
    procedure_performed_links = [],
    diagnosis_links = []
  )
    base = File.basename(entry.name, ".xml")
    output_dir = Rails.root.join("output", base)
    FileUtils.mkdir_p(output_dir)

    # 1) Write individual resource JSON files
    File.write(output_dir.join("patient_#{patient.id}.json"), patient.to_json)

    encounters = Array(encounter_results).map { |r| r[:encounter] }.compact
    conditions = Array(encounter_results).flat_map { |r| Array(r[:conditions]) }.compact
    medications = Array(medication_links).map { |ml| ml[:resource] }.compact
    assessments = Array(assessment_links).map { |al| al[:resource] }.compact
    intervention_orders = Array(intervention_order_links).map { |l| l[:resource] }.compact
    intervention_performeds = Array(intervention_performed_links).map { |l| l[:resource] }.compact
    procedure_performeds = Array(procedure_performed_links).map { |l| l[:resource] }.compact
    standalone_diagnoses = Array(diagnosis_links).map { |l| l[:resource] }.compact

    encounters.each { |e| File.write(output_dir.join("encounter_#{e.id}.json"), e.to_json) }
    conditions.each { |c| File.write(output_dir.join("condition_#{c.id}.json"), c.to_json) }
    medications.each do |m|
      # Name discharge meds explicitly for easier manual testing/validation.
      # Semantically they may be represented as MedicationRequest (category=discharge)
      # depending on measure alignment rules.
      link = medication_links.find { |ml| ml[:resource].object_id == m.object_id }
      kind = link && link[:kind]

      prefix =
        if kind == "discharge"
          "medication_discharge"
        else
          m.resourceType.downcase
        end

      File.write(output_dir.join("#{prefix}_#{m.id}.json"), m.to_json)
    end
    assessments.each { |o| File.write(output_dir.join("observation_#{o.id}.json"), o.to_json) }
    intervention_orders.each { |sr| File.write(output_dir.join("servicerequest_#{sr.id}.json"), sr.to_json) }
    intervention_performeds.each do |r|
      # Procedures and any linked result observations (which are Observations) share this list.
      if r.resourceType == "Procedure"
        File.write(output_dir.join("procedure_#{r.id}.json"), r.to_json)
      else
        File.write(output_dir.join("#{r.resourceType.downcase}_#{r.id}.json"), r.to_json)
      end
    end
    procedure_performeds.each { |p| File.write(output_dir.join("procedure_#{p.id}.json"), p.to_json) }
    standalone_diagnoses.each { |c| File.write(output_dir.join("condition_#{c.id}.json"), c.to_json) }

    # 2) Build a single bundle as a wrapper around all resources
    entries = []
    BundleBuilder.add(entries, patient)
    encounters.each { |e| BundleBuilder.add(entries, e) }
    conditions.each { |c| BundleBuilder.add(entries, c) }
    medications.each { |m| BundleBuilder.add(entries, m) }
    assessments.each { |o| BundleBuilder.add(entries, o) }
    intervention_orders.each { |sr| BundleBuilder.add(entries, sr) }
    intervention_performeds.each { |r| BundleBuilder.add(entries, r) }
    procedure_performeds.each { |p| BundleBuilder.add(entries, p) }
    standalone_diagnoses.each { |c| BundleBuilder.add(entries, c) }

    bundle = FHIR::Bundle.new(
      id: SecureRandom.uuid,
      type: "collection",
      entry: entries
    )

    File.write(output_dir.join("bundle_collection_#{patient.id}.json"), bundle.to_json)

    output_dir
  end

  # Upload in dependency order to reduce reference-not-found errors:
  # Patient -> Conditions -> Encounters -> everything else
  def upload_to_fhir_server(
    output_dir:,
    patient:,
    encounter_results:,
    medication_links:,
    assessment_links:,
    intervention_order_links:,
    intervention_performed_links:,
    procedure_performed_links:,
    diagnosis_links:
  )
    base_url = ENV.fetch("FHIR_BASE_URL", "http://127.0.0.1:8080/fhir")
    uploader = FhirUploader.new(base_url: base_url)

    # Match the manual curl flow you shared:
    # 1) PUT Patient
    # 2) PUT discharge medication
    # 3) PUT Encounter
    encounters = Array(encounter_results).map { |r| r[:encounter] }.compact

    discharge_med_resources =
      Array(medication_links).select { |ml| ml[:kind].to_s.strip == "discharge" }.map { |ml| ml[:resource] }.compact

    # Upload only the first discharge med + first encounter (same as the example curl sequence),
    # but still record all attempted uploads in the result JSON.
    to_upload = []
    to_upload << patient
    to_upload << discharge_med_resources.first if discharge_med_resources.any?
    to_upload << encounters.first if encounters.any?

    upload_result = uploader.upload_resources(to_upload)

    # 4) evaluate-measure and capture response
    evaluator = FhirMeasureEvaluator.new(base_url: base_url)
    measure_id = "CMS506FHIRSafeUseofOpioids"
    subject_ref = "Patient/#{patient.id}"

    # Default measurement period matches your curl example; can be overridden if needed.
    period_start = ENV.fetch("MEASURE_PERIOD_START", "2025-01-01")
    period_end = ENV.fetch("MEASURE_PERIOD_END", "2025-12-31")

    eval_result =
      begin
        evaluator.evaluate_measure(
          measure_id: measure_id,
          subject_ref: subject_ref,
          period_start: period_start,
          period_end: period_end
        )
      rescue StandardError => e
        {
          url: "#{base_url}/Measure/#{measure_id}/$evaluate-measure",
          status: nil,
          error: {
            exception: e.class.to_s,
            message: e.message.to_s,
            backtrace: Array(e.backtrace).first(30)
          }
        }
      end

    # Persist the MeasureReport JSON (response body) as its own file for easy access.
    if eval_result.is_a?(Hash) && eval_result[:body]
      File.write(output_dir.join("measure_evaluate_result.json"), eval_result[:body].to_s)
    end

    {
      output_dir: output_dir.to_s,
      base_url: base_url,
      upload: upload_result,
      evaluate_measure: eval_result
    }
  end
end
