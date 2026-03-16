# frozen_string_literal: true

# app/helpers/form_label_helper.rb
module FormLabelHelper
  def label_value(form, field)
    has_errors?(form, field) ? field_error_message(form, field) : field.to_s.capitalize
  end

  def form_label_css(form, field)
    class_names(
      "text-sm font-medium",
      {
        "text-red-600": has_errors?(form, field),
        "text-stone-700": !has_errors?(form, field)
      }
    )
  end

  private

  def field_error_message(form, field)
    form.object.errors.full_messages_for(field).first
  end

  def has_errors?(form, field)
    form.object.errors.full_messages_for(field).any?
  end
end
