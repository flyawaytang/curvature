require 'net/http'
require 'json'
require 'uri'
require 'ropenstack'

##
# Application controller, parent class to all other controllers, provides all methods which are used in
# multiple controllers
#
class ApplicationController < ActionController::Base
  rescue_from Ropenstack::RopenstackError, :with => :error_respond

  private

  ##
  # Manages the errors caught by the resuce_from Ropenstack::RopenstackError
  # Catches the type of error it is, creates a nice message and then returns the
  # request with the correct http code to match the error.
  #
  def error_respond(exception)
    case exception
    when Ropenstack::NotFoundError then
      code = 404
      message = "Unable to locate on openstack, 404 - Not Found Exception"
    when Ropenstack::UnauthorisedError then
      code = 401
      flash[:error] ||= "Invalid token!"
      message = "You are unauthorised to perform this action on openstack."
    when Ropenstack::TimeoutError then
      code = 503
      message = "Connecting to openstack took to long." +
                "Please check your connection and try again."
    else
      code = 500
      message = "There has been an error on openstack."
    end	
  
    exp = JSON.parse(exception.to_s)

    respond_to do |format|
      format.json { render :json => {"message" => message, "details" => exp}, :status => code }
    end
  end
  
  ##
  # A simple helper function which provides the 'respond_to do' for a list
  # to be returned in the json format.
  #
  def json_respond(list) 
    respond_to do |format|
      format.json{ render :json => list }
    end
  end

  # -----------------------------------------------------------------------
  # :section: Rest Utility Functions
  # This section of the Application controller provides function wrappers for
  # the basic http requested needed to talk to a REST API.
  # -----------------------------------------------------------------------

  ##
  # Build a http request using the URI specified, sets the timeout of the 
  # operation to 10 seconds for both opening the connection and reading.
  #
  def build_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 60
    http.read_timeout = 60
    return http
  end

  ##
  # Build the headers required to make a rest request, specifiying content type
  # and including the users token if it exists as the X-Auth-Token header.
  #
  def build_headers(token)
    headers = {'Content-Type' =>'application/json'}
    unless token.nil? 
      headers['X-Auth-Token'] = token
    end
    return headers
  end

  ##
  # Get request wrapper function
  # returns a HTTPResponse object
  #
  def get_request(uri, token)
    http = build_http(uri)
    request = Net::HTTP::Get.new(uri.request_uri, initheader = build_headers(token))
    return http.request(request)
  end

  ##
  # Delete request wrapper function
  # returns a HTTPResponse object
  #
  def delete_request(uri)
    http = build_http(uri)
    request = Net::HTTP::Delete.new(uri.request_uri, initheader = build_headers())
    return http.request(request)
  end

  ##
  # Put request wrapper function
  # returns a HTTPResponse object
  #
  def put_request(uri, body, token)
    http = build_http(uri)
    request = Net::HTTP::Put.new(uri.request_uri, initheader = build_headers(token))
    request.body = body
    return http.request(request)		
  end

  ##
  # Post request wrapper function
  # returns a HTTPResponse object
  #
  def post_request(uri, body, token)
    http = build_http(uri)
    request = Net::HTTP::Post.new(uri.request_uri, initheader = build_headers(token))
    request.body = body
    return http.request(request)		
  end

  # ---------------------------------------------------------------------------
  # :section: Ropenstack Wrappers
  # This section provides wrapper functionc for the creation of ropenstack objects
  # for use in the controllers. They make sure to create the object with the correct
  # data pulled in from the cookie.
  # ---------------------------------------------------------------------------
  
  ##
  # Returns a Ropenstack compute object created with the users token and stored compute ip
  # address
  #
  def compute()
    computeIP = URI.parse(sesh :compute_ip)
    return Ropenstack::Compute.new(computeIP, (sesh :current_token))
  end

  ##
  # Returns a Ropenstack blockStorage object created with the users token and stored blockStorage ip
  # address
  #
  def blockstorage()
    blockStorageIP = URI.parse(sesh :blockStorage_ip)
    return Ropenstack::BlockStorage.new(blockStorageIP, (sesh :current_token))
  end

  ##
  # Returns a Ropenstack networking object created with the users token and stored networking ip
  # address
  #
  def networking()
    networkingIP = URI.parse(sesh :network_ip)
    return Ropenstack::Networking.new(networkingIP, (sesh :current_token))
  end

  ##
  # Returns a Ropenstack image object created with the users token and stored glace ip
  # address
  #
  def image()
    imageIP = URI.parse(sesh :image_ip)
    return Ropenstack::Image.new(imageIP, (sesh :current_token))
  end

  # --------------------------------------------------------------------------------
  # :section: Cookies
  # Functions to do with the management and storage of data in the cookie.
  # --------------------------------------------------------------------------------

  ## Session/Cookie management :D 
  def sesh(name, value=nil)
    unless name.is_a? Symbol
      name = name.parameterize.underscore.to_sym
    end

    unless cookies.has_key?(:sesh_id)
      @sess = Storage.new
      @sess.data = {}.to_json
      @sess.save
    end

    unless defined? @sess 
      @sess = Storage.find(cookies[:sesh_id])
    end
    
    data = JSON.parse(@sess.data, :symbolize_names => true)

    unless value.nil? 
      data[name] = value
      @sess.data = data.to_json
      @sess.save
    end 
    cookies[:sesh_id] = @sess.id
    data[name]
  end

  # :section:

  ##
  # Returns true or false only based on if the user is logged in or not
  #
  def logged_in?
    !!cookies[:sesh_id]
  end
end
