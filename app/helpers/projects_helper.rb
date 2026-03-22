module ProjectsHelper
  def dataset_status_badge_classes(status)
    case status.to_s
    when "completed"
      "bg-emerald-100 text-emerald-800"
    when "failed"
      "bg-rose-100 text-rose-800"
    when "processing"
      "bg-amber-100 text-amber-800"
    else
      "bg-sky-100 text-sky-800"
    end
  end
end
