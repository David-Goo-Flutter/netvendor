class ApplicationController < ActionController::API
  private

  # Every error response has the same shape: { "error": { "code": "...", "message": "..." } }
  def render_error(code, message, status: :unprocessable_content)
    render json: { error: { code: code.to_s, message: message } }, status: status
  end
end
