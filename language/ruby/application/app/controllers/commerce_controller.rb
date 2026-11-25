require 'json'

class CommerceController < ActionController::Base
  skip_forgery_protection

  def health
    render json: { 'status' => 'ok' }
  end

  def assistant
    payload = JSON.parse(request.raw_post) rescue {}
    result = CommerceCopilot::AgentService.new(
      live: ENV['COMMERCE_LIVE'] == '1'
    ).run(
      tenant: request.headers['X-Tenant'].to_s,
      message: payload['message'].to_s
    )
    render json: result.body, status: result.status
  end
end
