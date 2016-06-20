# frozen_string_literal: true
class WebhookController < ApplicationController
  skip_before_action :verify_authenticity_token, :authenticate_user!,
                     :set_organization, :authorize_organization_access

  before_action :verify_organization_presence
  before_action :verify_payload_signature
  before_action :verify_sender_presence

  def events
    case request.headers['X-GitHub-Event']
    when 'ping'
      update_org_hook_status
    when 'release'
      verify_repo_presence
      handle_release_event
    else
      render nothing: true, status: 200
    end
  end

  private

  def verify_sender_presence
    @sender ||= User.find_by(uid: params.dig(:sender, :id))
    not_found unless @sender.present?
  end

  def verify_organization_presence
    @organization ||= Organization.find_by(github_id: params.dig(:organization, :id))
    not_found unless @organization.present?
  end

  def verify_payload_signature
    algorithm, signature = request.headers['X-Hub-Signature'].split('=')

    payload_validated = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new(algorithm),
                                                ENV['WEBHOOK_SECRET'],
                                                request.body.read) == signature
    not_found unless payload_validated
  end

  def update_org_hook_status
    unless @organization.is_webhook_active?
      @organization.update_attributes(is_webhook_active: true)
    end
    render nothing: true, status: 200
  end

  def verify_repo_presence
    not_found unless student_assignment_repo.present?
  end

  def student_assignment_repo
    repo_id = params.dig(:repository, :id)
    @assignment_repo ||= AssignmentRepo.find_by(github_repo_id: repo_id)
    @assignment_repo ||= GroupAssignmentRepo.find_by(github_repo_id: repo_id)
  end

  def handle_release_event
    render nothing: true, status: 200
  end
end
