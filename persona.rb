# -*- coding: utf-8 -*-
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

require 'builder'
require 'json'
require 'net/http'

module Chooser
  class Persona
    
    def self.verify_assertion(assertion)
      request = JSON.generate(
        "assertion" => assertion,
        "audience" => "https://favcolor.net:443/")

      uri = URI("https://verifier.login.persona.org/verify")
      post = Net::HTTP::Post.new(uri.path)
      post.body = request 
      post['Content-Type'] = 'application/json'
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      response = http.request(post)
      if !response.kind_of?(Net::HTTPSuccess)
        puts "OUCH! #{response}"
        nil
      else
        payload = JSON.parse(response.body)
        if payload['status'] != 'okay'
          return nil
        else
          return { 
            "displayName" => payload['email'],
            "email" => payload['email'],
            "providerId" => "persona.org" 
          }
        end
      end
    end
  end
end
