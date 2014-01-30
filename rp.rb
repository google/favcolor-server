# encoding: utf-8
# Copyright 2012-14 Google Inc.
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
require 'net/http'
require 'uri'
require 'json'
require 'google-id-token'

module Chooser

  G_AUTH_BASE = 'https://accounts.google.com/o/oauth2/auth'
  G_CLIENT_ID = ENV['GOOGLE_CLIENT_ID']
  G_CLIENT_SECRET = ENV['GOOGLE_CLIENT_SECRET']
  G_FETCH_REDIR = 'gauth-fetch-redirect'
  G_SCOPE = "openid email profile"
  G_TOKEN_BASE = 'https://accounts.google.com/o/oauth2/token'
  G_USERINFO_BASE = 'https://www.googleapis.com/oauth2/v1/userinfo'

  FB_APP_ID = ENV['FACEBOOK_APP_ID']
  FB_APP_SECRET = ENV['FACEBOOK_APP_SECRET']
  FB_AUTH_BASE = 'https://www.facebook.com/dialog/oauth'
  FB_REDIR = 'fbauth-redirect'
  FB_SCOPE = 'email publish_actions'
  FB_TOKEN_BASE = 'https://graph.facebook.com/oauth/access_token'
  FB_USERINFO_BASE = 'https://graph.facebook.com/me'

  LIVE_AUTH_BASE = 'https://login.live.com/oauth20_authorize.srf'
  LIVE_CLIENT_ID = ENV['LIVE_CLIENT_ID']
  LIVE_CLIENT_SECRET = ENV['LIVE_CLIENT_SECRET']
  LIVE_REDIR = 'mauth-redirect'
  LIVE_SCOPE = "wl.signin wl.basic wl.emails"
  LIVE_TOKEN_BASE = 'https://login.live.com/oauth20_token.srf'
  LIVE_USERINFO_BASE = 'https://apis.live.net/v5.0/me'

  WEB_CLIENT_ID = ENV['WEB_CLIENT_ID']
  WEB_CLIENT_SECRET = ENV['WEB_CLIENT_SECRET']
  ANDROID_CLIENT_ID = ENV['ANDROID_CLIENT_ID']

  PROVIDER_NAMES = {
    :google => 'google.com', :facebook => 'facebook.com', :live => 'live.com',
    :persona => 'persona.org'
  }

  class RP # relying party

    def self.provider_name(provider)
      PROVIDER_NAMES[provider]
    end

    def self.providers
      ' accountchooser.CONFIG.providers = ' +
        '[ "google.com", "facebook.com", "live.com", "persona.org" ];'
    end

    def self.from_id_token(token)
      validator = GoogleIDToken::Validator.new
      validator.check(token, WEB_CLIENT_ID)
    end

    def self.auth_uri(params, request, state)
      provider = params['providerId']
      email = params['email']
      case provider
      when 'google.com'
        google_auth_uri(request, email, state)
      when 'facebook.com'
        fb_auth_uri(request, email, state)
      when 'live.com'
        live_auth_uri(request, email)
      when 'persona.org'
        persona_auth_uri(email)
      else
        nil
      end
    end

    def self.persona_auth_uri(email = "")
      "https://favcolor.net/persona-sign-in?email=#{email}"
    end

    def self.fb_auth_uri(request, email, state)
      params = "client_id=#{FB_APP_ID}"
      params += "&redirect_uri=#{RP::redirect_uri(request, FB_REDIR)}"
      params += "&scope=#{FB_SCOPE}"
      if email
        params += "&state=#{state}"
      end
      FB_AUTH_BASE + '?' + URI.escape(params)
    end

    def self.google_auth_uri(request, email, state)
      params = "client_id=#{G_CLIENT_ID}"
      params += "&state=#{state}" if state
      params += "&scope=openid email profile"
      params +=
        "&redirect_uri=#{RP::redirect_uri(request, G_FETCH_REDIR)}"
      params += "&response_type=code"
      if email
        params += "&login_hint=#{email}" 
      end
      G_AUTH_BASE + '?' + URI.escape(params)
    end

    def self.live_auth_uri(request, email = nil)
      params = "client_id=#{LIVE_CLIENT_ID}"
      params += "&scope=#{LIVE_SCOPE}"
      params += "&response_type=code"
      params += "&redirect_uri=https://favcolor.net/liveauth-redirect"
      LIVE_AUTH_BASE + '?' + URI.escape(params)
    end

    def self.fetch_account(idp, code, request)
      case idp
      when :facebook
        fetch_fb_account(code, request)
      when :google
        fetch_google_account(code, request)
      when :live
        fetch_live_account(code, request)
      end
    end

    def self.fetch_fb_account(code, request)
      # fetch token
      params = {
        'code' => code,
        'client_id' => FB_APP_ID,
        'client_secret' => FB_APP_SECRET,
        'redirect_uri' => RP::redirect_uri(request, FB_REDIR)
      }
      uri = URI(FB_TOKEN_BASE)
      post = Net::HTTP::Post.new(uri.path)
      post['Content-Type'] = 'application/x-www-form-urlencoded'
      post.set_form_data params

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(post)

      if !response.kind_of?(Net::HTTPSuccess)
        response.value # throws an exception
      end

      token = Hash[URI::decode_www_form(response.body)]['access_token']

      # fetch userinfo
      uri = URI FB_USERINFO_BASE
      get = Net::HTTP::Get.new uri.request_uri
      get['Authorization'] = 'Bearer ' + token
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(get)

      if !response.kind_of?(Net::HTTPSuccess)
        response.value # throws an exception
      end

      # parse json & twiddle field names
      json = JSON.parse(response.body)
      json['displayName'] = json['name']
      json['photoUrl'] = "https://graph.facebook.com/#{json['id']}/picture"
      json['providerId'] = 'facebook.com'
      json
    end

    def self.fetch_google_account(code, request)

      # fetch token
      params = {
        'code' => code,
        'client_id' => G_CLIENT_ID,
        'client_secret' => G_CLIENT_SECRET,
        'redirect_uri' => RP::redirect_uri(request, G_FETCH_REDIR),
        'grant_type' => 'authorization_code'
      }
      uri = URI(G_TOKEN_BASE)
      post = Net::HTTP::Post.new(uri.path)
      post['Content-Type'] = 'application/x-www-form-urlencoded'
      post.set_form_data params

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(post)

      if !response.kind_of?(Net::HTTPSuccess)
        response.value # throws an exception
      end

      token = JSON.parse(response.body)['access_token']

      # fetch userinfo
      uri = URI G_USERINFO_BASE
      get = Net::HTTP::Get.new uri.request_uri
      get['Authorization'] = 'Bearer ' + token

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(get)

      if !response.kind_of?(Net::HTTPSuccess)
        response.value # throws an exception
      end

      # parse json & twiddle field names
      json = JSON.parse(response.body)
      json['displayName'] = json['name'] if json['name']
      json['photoUrl'] = json['picture'] if json['picture']
      json['providerId'] = 'google.com'
      json
    end

    def self.fetch_live_account(code, request)
      # fetch token
      params = {
        'code' => code,
        'client_id' => LIVE_CLIENT_ID,
        'client_secret' => LIVE_CLIENT_SECRET,
        'redirect_uri' => 'https://favcolor.net/liveauth-redirect',
        'grant_type' => 'authorization_code'
      }
      uri = URI(LIVE_TOKEN_BASE)
      post = Net::HTTP::Post.new(uri.path)
      post['Content-Type'] = 'application/x-www-form-urlencoded'
      post.set_form_data params

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(post)

      if !response.kind_of?(Net::HTTPSuccess)
        response.value # throws an exception
      end

      body = response.body
      token = JSON.parse(body)['access_token']

      # fetch userinfo
      uri = URI LIVE_USERINFO_BASE
      get = Net::HTTP::Get.new(uri.request_uri)
      get['Authorization'] = 'Bearer ' + token

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(get)

      # parse json & twiddle field names
      body = response.body
      json = JSON.parse(body)
      json['email'] = json['emails']['account']
      json['displayName'] = json['name'] if json['name']
      json['photoUrl'] = json['picture'] if json['picture']
      json['providerId'] = 'live.com'
      json

    end

    def self.redirect_uri(req, redirect)
      "https://favcolor.net/#{redirect}"
    end
  end
end
