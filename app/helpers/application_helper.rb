module ApplicationHelper
  def flash_tone_classes(type)
    case type.to_s
    when "notice"
      "border-emerald-200 bg-emerald-50 text-emerald-800"
    when "alert"
      "border-rose-200 bg-rose-50 text-rose-800"
    else
      "border-stone-200 bg-white text-stone-800"
    end
  end
end
