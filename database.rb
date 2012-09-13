require 'json'
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

  class Database
    DIR='./accounts'
    def initialize
      @accounts = {}
      Dir.entries(DIR).grep(/@/).each do |f|
        a = Account.new(JSON.parse(File.read "#{DIR}/#{f}"))
        @accounts[a['email']] = a
      end
    end

    def find(email)
      @accounts[email]
    end

    def save(account)
      name = account['email']
      @accounts[name] = account unless @accounts[name]
      File.write("#{DIR}/#{name}", account.to_s)      
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
