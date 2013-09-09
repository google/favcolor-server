# encoding: utf-8
# Copyright 2012 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#  
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'json'
require 'jwt'
require 'openssl'
require 'sandal'
require 'mail'
require 'builder'

module Chooser

  class GAT

    GOOGLE_API_URL = "https://www-googleapis-staging.sandbox.google.com/rpc"
    OOB_CODE_URL = "https://www.googleapis.com/identitytoolkit/v3/relyingparty/getOobConfirmationCode"
    FAVCOLOR_1_SERVICE_EMAIL = ENV['FAVCOLOR_1_SERVICE_EMAIL']
    FAVCOLOR_2_SERVICE_EMAIL = ENV['FAVCOLOR_2_SERVICE_EMAIL']
    SERVICE_EMAIL = FAVCOLOR_2_SERVICE_EMAIL
    GITKIT_SCOPE = 'https://www.googleapis.com/auth/identitytoolkit'
    TOKEN_ENDPOINT = 'https://accounts.google.com/o/oauth2/token'
    GAT_CALLBACK= 'https://favcolor.net/gat-callback'
    GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:jwt-bearer'
    FAVCOLOR_1_KEY = ENV['FAVCOLOR_1_KEY']
    FAVCOLOR_2_KEY = ENV['FAVCOLOR_2_KEY']
    FAVCOLOR_KEY = FAVCOLOR_2_KEY

    def self.get_session(request, database)
      cookie = request.cookies['git']
      if !cookie
        return nil
      end

      # GAT login successful
      gat_token = GAT.validate_cookie cookie
      if !gat_token
        # cookie didn't validate... Maybe expired?
        return nil
      end

      # token checks out
      email = gat_token['email']
      puts "GAT Cookie"
      gat_token.each {|k,v| puts " T[#{k}] = #{v}"}

      # if this is a new account, blast it into the database
      if database.find_account(email) == nil
        # new account
        account = GAT.get_user_info(cookie)
        database.save_account(Account.new(account))
      end
 
      return email
    end

    def self.login_page(host)
      scripts = GITKIT_JS + "\n" + SIGNIN_SETUP
      scripts.gsub!("_BRANDING_", GAT.branding(host))
      subs = { 
        "_H2_" => "Welcome to FavColor",
        "_GAT_ID_" => "navbar",
        "_PAYLOAD_" => "<p>You’re not signed in, so we don’t know your favorite color.</p>" 
      }
      body = signin_body.dup
      subs.each { |k, v| body.gsub!(k, v) }
      p = "<!DOCTYPE html>\n<html>\n" +
        FAVCOLOR_HEAD.gsub("_SCRIPTS_", scripts) +
        body +
        "</html>"
    end

    def self.normal_page(host, h2 = nil)
      return GAT.new(host, h2)
    end

    def make_normal_page(host)
      scripts = GITKIT_JS + "\n" + SIGNIN_SETUP
      scripts.gsub!("_BRANDING_", GAT.branding(host))
      subs = {
        "_GAT_ID_" => "navbar",
      }
      body = GAT.signin_body.dup
      subs.each { |k, v| body.gsub!(k, v) }
      "<html>\n" +
        FAVCOLOR_HEAD.gsub("_SCRIPTS_", scripts) +
        body +
        "</html>"
    end

    def initialize(host, h2)
      @page = make_normal_page(host)
      if h2
        h2!(h2)
      end
    end
    def h2!(title)
      @page.sub!('_H2_', title)
    end

    def self.callback_page(body)
      subs = {
        "_FAVCOLOR_KEY_" => FAVCOLOR_KEY,
        "_BODY_" => body
      }
      scripts = CAPTCHA_JS + GITKIT_JS + "\n" + CALLBACK_SETUP
      subs.each { |k, v| scripts.gsub!(k, v) }
      body = callback_body.gsub("_GAT_ID_", "gatDiv")
      "<html>\n" +
        FAVCOLOR_HEAD.gsub("_SCRIPTS_", scripts) +
        body +
        "</html>"
    end

    def self.branding(host)
      "https://#{host}/login-marketing"
    end

    def self.validate_cookie(cookie)
      pk = cert.public_key
      JWT.decode(cookie, pk, !!pk)
    end

    def self.cert
      if !@cert
        @cert = OpenSSL::X509::Certificate.new(File.read('gat-cert'))
      end
      @cert
    end

    def self.compute_bodies
      if !@signin_body
        @signin_body = compute_body(false)
        @callback_body = compute_body(true)
      end
    end

    def self.callback_body
      compute_bodies
      @callback_body
    end

    def self.signin_body
      compute_bodies
      @signin_body
    end

    def self.compute_body(callback)
      b = Builder::XmlMarkup.new(:indent => 2)
      s = b.body do
        b.div(:class => 'row-fluid', :id => 'container') do
          b.div(:class => 'span3', :id => 'left') do
            b.img(:src => 'g60s.png'); b.br
            b.img(:src => 'r96s.png'); b.br
            b.img(:src => 'b88s.png')
          end
          if callback
            b.div(:class => 'span2 offset6') do
              b.div(:id  => '_GAT_ID_', :style => 'float: right;')
            end
          else
            b.div(:class => 'span4') do
              b.h2("_H2_")
              b.script("/* */", :src => '/bootstrap/js/bootstrap.min.js')
              b.div("_PAYLOAD_")
            end
            b.div(:class => 'span3', :id => 'gatHolder') do
              b.div(:id  => '_GAT_ID_') 
            end
          end
        end
      end
      s.to_s
    end

    def h2!(title)
      @page.sub!('_H2_', title)
    end

    def payload!(s)
      @page.sub!('_PAYLOAD_', s)
    end

    def to_s
      @page.gsub('_PAYLOAD_', '')
    end

    def self.forgot(params, userIp)

      # 1. make a jwt for service-account authentication
      signer = Sandal::Sig::RS256.new(File.read('service.pem'))
      now = Time.now
      claims = {
        "iss" => SERVICE_EMAIL,
        "scope" => GITKIT_SCOPE,
        "aud" => "https://accounts.google.com/o/oauth2/token",
        "iat" => now.to_i,
        "exp" => (now + 3600).to_i
      }       
      jwt = Sandal.encode_token(claims, signer, { 'kid' => 'privatekey'})

      # 2. swap the jwt for an access token
      uri = URI(TOKEN_ENDPOINT)
      post = Net::HTTP::Post.new(uri.path)
      post.set_form_data( "grant_type" => GRANT_TYPE, "assertion" => jwt )
      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
        http.request(post)
      end   
      if !res.kind_of?(Net::HTTPSuccess)
        res.value # throws an exception
      end
      token = JSON.parse(res.body)['access_token']

      # 3. send recaptcha details off to get a one-time code
      request = JSON.generate(
        "kind" => "identitytoolkit#relyingparty",
        "requestType" => 1,
        "email" => params['email'],
        "challenge" => params['challenge'],
        "captchaResp" => params['response'],
        "userIp" => userIp
      )
      uri = URI(OOB_CODE_URL)
      post = Net::HTTP::Post.new(uri.path)
      post.body = request 
      post['Content-Type'] = 'application/json'
      post['Authorization'] = "Bearer #{token}"
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      response = http.request(post)
      if !response.kind_of?(Net::HTTPSuccess)
        response.value # throws an exception
      end   
      code = JSON.parse(response.body)['oobCode']
      
      # 4. send off an email with a password-recovery URL
      callback = "#{GAT_CALLBACK}?mode=forgot&code=#{code}"
      m_body = "Please visit #{callback} " +
        "to reset your password."
      mail = Mail.new do
        from    'favcolor@favcolor.net'
        to      params['email']
        subject 'Favcolor.net password reset'
        body    m_body 
      end     
      dm = mail.delivery_method
      dm.settings[:openssl_verify_mode]  = 'none'
      Mail.deliver mail
      return nil
    end

    def self.get_user_info(token)
      request = JSON.generate [ {
          'method' => 'identitytoolkit.relyingparty.getAccountInfo',
          'apiVersion' => 'v3',
          'params' => { 'idToken' => token }
        } ]
      uri = URI.parse GOOGLE_API_URL + '?key=' + FAVCOLOR_KEY
      post = Net::HTTP::Post.new(uri.path + "?" + uri.query)
      post.body = request
      post['Content-Type'] = 'application/json'
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      response = http.request(post)

      if !response.kind_of?(Net::HTTPSuccess)
        response.value # throws an exception
      end

      json = JSON.parse response.body
      json = json[0]
      json = json['result']
      json = json['users']
      json[0]
    end

SIGNIN_SETUP = <<EOFEOF
<script type="text/javascript">
  window.google.identitytoolkit.signInButton(
    '#navbar',
    {
      callbackUrl: "/gat-callback",
      logoutUrl: "/gat-signout",
      idps: ["google", "yahoo"],
      acuiconfig: {
        title: "FavColor + GAT",
        branding: "_BRANDING_"
      }
    }); </script>
EOFEOF

    CALLBACK_SETUP = <<EOFEOF
<script type="text/javascript">
  function load() {
    var config = {
      developerKey: "_FAVCOLOR_KEY_",
      callbackUrl: "/gat-callback",
      homeUrl: "/gat",
      forgotUrl: "/gat-forgot",
      logoutUrl: "/gat-signout",
      siteName: "FavColor + GAT",
      idps: ["google", "yahoo"]
    };
    google.identitytoolkit.handleGatOp(
      '#gatDiv', 
      config, 
      decodeURIComponent('_BODY_'));
  }
</script>
<script type="text/javascript" src="//apis.google.com/js/client.js?onload=load"></script>
EOFEOF

    GITKIT_JS = <<EOFEOF
<script type="text/javascript" src="//www.accountchooser.com/client.js"></script>
<script type="text/javascript" src="//www.gstatic.com/authtoolkit/js/gitkit.js"></script>
<link type="text/css" rel="stylesheet" href="//www.gstatic.com/authtoolkit/css/gitkit.css" />
EOFEOF
    
    CAPTCHA_JS = <<EOFEOF
<script type="text/javascript" src="//www.google.com/recaptcha/api/js/recaptcha_ajax.js"></script>
EOFEOF

    FAVCOLOR_HEAD = "<head>" +
      "<script type=\"text/javascript\" src=\"jscolor/jscolor.js\"></script>\n" +
      "<link rel='stylesheet' type='text/css' href='/chooser.css' />\n" +
      "<title>FavColor: We Know Your Favorite!</title>\n" +
      "<link href=\"/bootstrap/css/bootstrap.min.css\" rel=\"stylesheet\" />\n" +
      "_SCRIPTS_" +
      "</head>"
  end
end
