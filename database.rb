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

module Chooser

  class Database
    A_DIR='./accounts'
    S_DIR='./states'
    STATE_LIFETIME = 10.0

    def initialize
      @accounts = {}

      Dir.entries(A_DIR).grep(/@/).each do |f|
        a = Account.new(JSON.parse(File.read "#{A_DIR}/#{f}"))
        @accounts[a['email']] = a
      end
    end

    def get_state state
      # TODO: Clean up states directory
      return nil unless state
      f = File.new "#{S_DIR}/#{state}"
      if File.exists? f
        File.read f
      else
        nil
      end
    end

    def set_state(state, value)
      state = File.open("#{S_DIR}/#{state}", "w")
      state.write value
      state.close
    end

    def find_account(email)
      @accounts[email]
    end

    def save_account(account)
      name = account['email']
      @accounts[name] = account unless @accounts[name]
      File.write("#{A_DIR}/#{name}", account.to_s)      
    end
  end

  class Account

    def initialize(fields)
      @fields = fields
    end

    def [](name)
      @fields[name]
    end

    def []=(name, value)
      @fields[name] = value
    end

    def to_s
      JSON.generate @fields
    end

    def check_password(password)
      @fields['password'].eql? password
    end

  end


end
