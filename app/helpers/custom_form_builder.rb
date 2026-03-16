# frozen_string_literal: true

# app/helpers/custom_form_builder.rb
class CustomFormBuilder < ActionView::Helpers::FormBuilder
  def text_field(attribute, options = {})
    super(attribute, options.merge(class: input_class))
  end

  def textarea(attribute, options = {})
    super(attribute, options.merge(class: input_class))
  end

  def input_class
    "w-full rounded-2xl border border-stone-300 bg-white px-4 py-3 text-sm text-stone-900 outline-none transition placeholder:text-stone-400 focus:border-stone-900 focus:ring-2 focus:ring-stone-200"
  end
end
