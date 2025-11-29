module ApplicationHelper
	

	def model_error(model, model_attr)
		result = ""
		if model.errors[model_attr].any?
			model.errors[model_attr].each do |message|
				result += "<span class='errors'> #{message}</span>"
			end
		end
		return "#{result}".html_safe
	end
end
