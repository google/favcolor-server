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

module Chooser

  require 'multi_json'
  require 'jwt'
  require 'openssl'
  require 'net/http'

  GOOGLE_CERTS_URI = 'https://www.googleapis.com/oauth2/v1/certs'

  class IDTokenChecker

    attr_reader :problem

    def initialize
      @certificates = {}
      refresh_certs
    end

    # If it works, returns a has with the JWT fields from the ID Token.
    #  You have to provide an "aud" field, and will check cid if provided.
    # If something fails, returns nil and you call @problem to get some
    #  error text
    def check(token, aud, cid = nil)
      check_cached_certs(token, aud, cid)
      return nil if @problem

      if !@token
        refresh_certs
        check_cached_certs(token, aud, cid)
        return nil if @problem

        if !@token
          @problem = 'Cannot verify against any current Google certificate'
        end
      end

      @token
    end

    private

    def check_cached_certs(token, aud, cid)
      @certificates.detect do |key, cert|
        check_one(token, cert.public_key, aud, cid)
      end
    end

    def refresh_certs
      uri = URI GOOGLE_CERTS_URI
      get = Net::HTTP::Get.new uri.request_uri
      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
        http.request(get)
      end

      if !res.kind_of?(Net::HTTPSuccess)
        res.value # throws an exception
      end

      new_certs = Hash[MultiJson.load(res.body).map do |key, cert|
                         [key, OpenSSL::X509::Certificate.new(cert)]
                       end]
      @certificates.merge! new_certs
    end

    def check_one(token, public_key, aud, cid)
      @token = @problem = nil
      begin
        decoded = JWT.decode(token, public_key, !!public_key)
        if !(decoded.has_key?('aud') && decoded['aud'] == aud)
          @problem = 'Token audience mismatch'
        end
        if cid && !(decoded.has_key?('cid') && decoded['cid'] == cid)
          @problem = 'Token client-id mismatch'
        end
        if !problem
          @token = decoded
        end

      rescue JWT::DecodeError
        # this is a normal case, since there are multiple certs
      end

      @token || @problem
    end
  end
end
