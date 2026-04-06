module StatusCodeHelper
  # Map QRDA/CDA status codes into base-FHIR allowed codes.
  #
  # Resource-specific allowed sets differ, so we provide a small set of helpers.
  # If an input code doesn't map, we return a safe default that is valid for that resource.
  def map_encounter_status(code)
    case normalize(code)
    when "completed"
      "finished"
    when "in-progress", "active"
      "in-progress"
    when "cancelled", "canceled", "aborted"
      "cancelled"
    when "planned", "new"
      "planned"
    else
      "unknown"
    end
  end
  module_function :map_encounter_status
  alias_method :extract_status_code, :map_encounter_status
  module_function :extract_status_code
  public :extract_status_code
  module_function :public
rescue StandardError
  # no-op for module_function/public in older rubies
end

module StatusCodeHelper
  def map_med_admin_status(code)
    case normalize(code)
    when "completed", "performed"
      "completed"
    when "in-progress", "active"
      "in-progress"
    when "not-done", "not_done"
      "not-done"
    when "entered-in-error"
      "entered-in-error"
    when "stopped", "cancelled", "canceled"
      "stopped"
    else
      "unknown"
    end
  end
  module_function :map_med_admin_status

  def map_med_request_status(code, negation_ind: false)
    return "cancelled" if negation_ind

    case normalize(code)
    when "active", "in-progress"
      "active"
    when "completed"
      "completed"
    when "stopped"
      "stopped"
    when "draft", "new", "planned"
      "draft"
    when "cancelled", "canceled"
      "cancelled"
    when "entered-in-error"
      "entered-in-error"
    else
      "active"
    end
  end
  module_function :map_med_request_status

  def map_med_statement_status(code, negation_ind: false)
    return "not-taken" if negation_ind

    case normalize(code)
    when "active", "in-progress"
      "active"
    when "completed"
      "completed"
    when "stopped"
      "stopped"
    when "entered-in-error"
      "entered-in-error"
    when "unknown"
      "unknown"
    else
      "active"
    end
  end
  module_function :map_med_statement_status

  def normalize(code)
    code.to_s.strip.downcase
  end
  module_function :normalize
end
