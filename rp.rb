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
require 'net/http'
require 'uri'
require 'json'

module Chooser

  AUTH_BASE = 'https://accounts.google.com/o/oauth2/auth'
  CLIENT_ID = '588522613324.apps.googleusercontent.com'
  CLIENT_SECRET = 'IeABV90daKbeB_cCyKPkSUjr'
  REDIRECT_URI = 'gauth-redirect'
  TOKEN_BASE = 'https://accounts.google.com/o/oauth2/token'
  USERINFO_BASE = 'https://www.googleapis.com/oauth2/v1/userinfo'

  class RP # relying party

    def self.google_auth_uri(request, email = nil)
      params = "client_id=#{CLIENT_ID}"
      params += "&redirect_uri=#{RP::redirect_uri(request)}"
      params += "&scope=openid profile email"
      params += "&response_type=code"
      if email
        params += "&user_id=#{email}" 
        params += "&state=#{email}"
      end
      AUTH_BASE + '?' + URI.escape(params)
    end

    def self.fetch_google_account(code, request)
      
      # fetch token
      params = {
        'code' => code,
        'client_id' => CLIENT_ID,
        'client_secret' => CLIENT_SECRET,
        'redirect_uri' => RP::redirect_uri(request),
        'grant_type' => 'authorization_code'
      }
      uri = URI(TOKEN_BASE)
      post = Net::HTTP::Post.new(uri.path)
      post.set_form_data params

      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
        http.request(post)
      end

      if !res.kind_of?(Net::HTTPSuccess)
        res.value # throws an exception
      end

      token = JSON.parse(res.body)['access_token']

      # fetch userinfo
      uri = URI(USERINFO_BASE)
      get = Net::HTTP::Get.new(uri.request_uri)
      get['Authorization'] = 'Bearer ' + token
      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
        http.request(get)
      end

      if !res.kind_of?(Net::HTTPSuccess)
        res.value # throws an exception
      end

      # parse json & twiddle field names
      json = JSON.parse(res.body)
      json['displayName'] = json['name']
      json['photoUrl'] = json['picture']
      json['authUrl'] = 'http://google.com'
      json
    end

    def self.redirect_uri req
      "#{req.scheme}://#{req.host}:#{req.port}/#{REDIRECT_URI}"
    end
  end
end
