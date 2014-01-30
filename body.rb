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
require 'uri'
require 'json'

module Chooser

  class Body
    def self.parse_form request
      request.body.rewind
      parse_parms(request.body.read)
    end

    def self.parse_parms string
      Hash[URI::decode_www_form(string)]
    end

    def self.parse_json request
      request.body.rewind
      JSON.parse(request.body.read)
    end
  end

end
