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

module Chooser

  class GAT

    GOOGLE_API_URL = "https://www-googleapis-staging.sandbox.google.com/rpc"
    OOB_CODE_URL = "https://www.googleapis.com/identitytoolkit/v3/relyingparty/getOobConfirmationCode"
    FAVCOLOR_4_SERVICE_EMAIL = ENV['FAVCOLOR_4_SERVICE_EMAIL']
    SERVICE_EMAIL = FAVCOLOR_4_SERVICE_EMAIL
    GITKIT_SCOPE = 'https://www.googleapis.com/auth/identitytoolkit'
    TOKEN_ENDPOINT = 'https://accounts.google.com/o/oauth2/token'
    GAT_CALLBACK= 'https://favcolor.net/gat-callback'
    GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:jwt-bearer'
    FAVCOLOR_4_KEY = ENV['FAVCOLOR_4_KEY']
    FAVCOLOR_KEY = FAVCOLOR_4_KEY

    DEFAULT_COLOR = "var fc_config = { rgb : [0x96, 0x60, 0x88], run : false };\n" 
    def self.get_session(request, database, token_string = nil)

      if token_string == nil
        token_string = request.cookies['git']
        if !token_string
          return nil
        end
      end

      # GAT login successful
      gat_token = GAT.validate_cookie token_string
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
        account = GAT.get_user_info(token_string)
        database.save_account(Account.new(account))
      end
 
      return email
    end

    def self.key
      FAVCOLOR_KEY
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

    def self.forgot(params, userIp)

      # 1. make a jwt for service-account authentication
      signer = Sandal::Sig::RS256.new(File.read('favcolor4.pem'))
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
      post['Content-Type'] = 'application/x-www-form-urlencoded'
      post.set_form_data( "grant_type" => GRANT_TYPE, "assertion" => jwt )
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(post)
      if !response.kind_of?(Net::HTTPSuccess)
        response.value # throws an exception
      end
      token = JSON.parse(response.body)['access_token']

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
      callback = "#{GAT_CALLBACK}?mode=forgot&oobCode=#{code}"
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
  end
end
