module StatusCodeHelper
  def extract_status_code(status_code)
    return "unknown" unless status_code
    # Normalize the status code to lowercase for consistent comparison
    status_code = status_code.downcase

    # Map the status code to a more descriptive term
    case status_code
    when "completed"
      "finished"
    when "in-progress"
      "in-progress"
    else
      "unknown"
    end
  end
end
