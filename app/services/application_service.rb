# frozen_string_literal: true

# app/services/application_service.rb
class ApplicationService
  def self.call(...)
    new(...).call
    # rescue RestClient::ExceptionWithResponse => e
    #  OpenStruct.new({ success?: false, error: e.message })
  end

  def handle_error(error)
    OpenStruct.new({ success?: false, error: error })
  end

  def handle_success(data)
    # Support both old pattern (result.data) and new pattern (result.key)
    # Only splat if data is a Hash, otherwise just wrap it
    if data.is_a?(Hash)
      OpenStruct.new({ success?: true, data: data, **data })
    else
      OpenStruct.new({ success?: true, data: data })
    end
  end
end
