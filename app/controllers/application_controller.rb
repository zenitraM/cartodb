# coding: UTF-8

class ApplicationController < ActionController::Base
  protect_from_forgery
  helper :all

  before_filter :browser_is_html5_compliant?, :app_host_required

  class NoHTML5Compliant < Exception; end;

  rescue_from NoHTML5Compliant, :with => :no_html5_compliant
  rescue_from RecordNotFound, :with => :render_404

  $progress ||= {}

  include SslRequirement

  unless Rails.env.production?
    def self.ssl_required(*splat)
      false
    end
    def self.ssl_allowed(*splat)
      true
    end
  end

  protected
  
  def app_host_required
    (request.host_with_port == APP_CONFIG[:app_host].host) || (render_api_endpoint and return false)
  end

  def render_404
    respond_to do |format|
      format.html do
        render :file => "public/404.html.erb", :status => 404, :layout => false
      end
      format.json do
        render :nothing => true, :status => 404
      end
    end
  end

  def render_api_endpoint
    respond_to do |format|
      format.html do
        render :file => "public/api.html.erb", :status => 404, :layout => false
      end
      format.json do
        render :nothing => true, :status => 404
      end
    end
  end
  def login_required
    authenticated? || not_authorized
  end

  def api_authorization_required
    authenticate!(:api_authentication)
  end

  def not_authorized
    respond_to do |format|
      format.html do
        redirect_to login_path and return
      end
      format.json do
        render :nothing => true, :status => 401
      end
    end
  end

  def table_privacy_text(table)
    table.private? ? 'PRIVATE' : 'PUBLIC'
  end
  helper_method :table_privacy_text

  def translate_error(exception)
    if exception.is_a?(String)
      return exception
    end
    case exception
      when CartoDB::EmtpyFile
        ERROR_CODES[:empty_file]
      when Sequel::DatabaseError
        if exception.message.include?("transform: couldn't project")
          ERROR_CODES[:geometries_error].merge(:raw_error => exception.message)
        else
          ERROR_CODES[:unknown_error].merge(:raw_error => exception.message)
        end
      else
        ERROR_CODES[:unknown_error].merge(:raw_error => exception.message)
    end.to_json
  end

  def no_html5_compliant
    render :file => "#{Rails.root}/public/HTML5.html", :status => 500, :layout => false
  end

  def api_request?
    request.subdomain.eql?('api')
  end
  
  def browser_is_html5_compliant?
    return true if Rails.env.test? || api_request?
    user_agent = request.user_agent.try(:downcase)
    unless user_agent.blank? || user_agent.match(/firefox\/4|safari\/5|chrome\/7/)
      raise NoHTML5Compliant
    end
  end
  
end
