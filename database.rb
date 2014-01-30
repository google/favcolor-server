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
require 'json'
require 'memcache'

module Chooser

  class Database
    A_DIR='./accounts'

    def initialize
      @accounts = {}
      @cache = Memcache.new(:server => "localhost:11211")
      @r = Random.new

      Dir.entries(A_DIR).grep(/@/).each do |f|
        a = Account.new(JSON.parse(File.read "#{A_DIR}/#{f}"))
        @accounts[a['email']] = a
      end
    end

    def get_state state
      return nil unless state
      @cache.get('state ' + state)
    end

    def set_state(state, value)
      @cache.set('state ' + state, value, :expiry => 120)
    end

    def set_share(email)
      key = @r.rand(489275195).to_s
      @cache.set('share '  + key, email, :expiry => 24 * 60 * 60)
      key
    end
    def get_share(key)
      @cache.get('share ' + key)
    end

    def find_account(email)
      @accounts[email]
    end

    def save_account(account)
      name = account['email']
      @accounts[name] = account
      File.write("#{A_DIR}/#{name}", account.to_s)      
    end
  end

  class Account

    def initialize(fields)
      @fields = fields
    end

    def idp_is_google?
      return true if @fields['providerId'] == 'google.com'
      providers = @fields['providerUserInfo']
      return false unless providers
      providers.find {|provider| provider['providerId'] == 'google.com'}
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
