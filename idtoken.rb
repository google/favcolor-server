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

##
# Validates strings alleged to be ID Tokens issued by Google; if validation
#  succeeds, returns the decoded ID Token as a hash.
# It's a good idea to keep an instance of this class around for a long time,
#  because it caches the keys, performs validation statically, and only
#  refreshes from Google when they expire (typically once per day)
#
# @author Tim Bray, adapted from code by Bob Aman
module Chooser

  require 'multi_json'
  require 'jwt'
  require 'openssl'
  require 'net/http'

  GOOGLE_CERTS_URI = 'https://www.googleapis.com/oauth2/v1/certs'

  class GoogleIdTokenVerifier

    # @!attribute [r] problem
    #   @return [String] reason for verification failure
    attr_reader :problem

    def initialize
      @certificates = {}
    end

    ##
    # If it works, returns a hash with the JWT fields from the ID Token.
    #  You have to provide an "aud" field, which must match the
    #  token's field with that name, and will similarly check cid if provided.
    # If something fails, returns nil; you can call #problem to get some
    #  error text
    # @note Will occasionally out to Google to retrieve validation
    #    certificates; in Nov 2012 these were flipped about once per day.
    #
    # @param [String] token
    #   The string form of the token
    # @param [String] aud
    #   The required audience value
    # @param [String] cid
    #   The optional client-id value
    #
    # @return [Hash] The decoded ID token, or null
    def check(token, aud, cid = nil)
      check_cached_certs(token, aud, cid)

      if @problem
        nil
      elsif @token
        @token
      else
        # No problem, but no validation; Google certs might have been flipped
        if refresh_certs
          @problem = 'Unable to retrieve Google public keys'
          nil
        else
          check_cached_certs(token, aud, cid)
          if @problem
            nil
          elsif @token
            @token
          else
            @problem = 'Cannot verify against any current Google certificate'
            nil
          end
        end
      end
    end

    private

    # tries to validate the token against each cached cert.
    # Sets @token (victory!), @problem (give up now), or nil
    #  (none of these certs worked)
    def check_cached_certs(token, aud, cid)
      @problem = @token = nil

      # find first public key that validates this token
      @certificates.detect do |key, cert|
        begin
          public_key = cert.public_key
          @token = JWT.decode(token, public_key, !!public_key)
        rescue JWT::DecodeError
          false
        end
      end


      if @token
        if !(@token.has_key?('aud') && @token['aud'] == aud)
          @problem = 'Token audience mismatch'
        elsif cid && !(@token.has_key?('cid') && @token['cid'] == cid)
          @problem = 'Token client-id mismatch'
        end
        @token = nil if @problem
      end
    end

    # returns true if there was a problem
    def refresh_certs
      uri = URI GOOGLE_CERTS_URI
      get = Net::HTTP::Get.new uri.request_uri
      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
        http.request(get)
      end

      if !res.kind_of?(Net::HTTPSuccess)
        true
      else
        new_certs = Hash[MultiJson.load(res.body).map do |key, cert|
                           [key, OpenSSL::X509::Certificate.new(cert)]
                         end]
        @certificates.merge! new_certs
        false
      end
    end
  end
end
