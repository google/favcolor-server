# -*- coding: utf-8 -*-
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
require 'builder'

module Chooser

  class Forms

    def self.login
      b = Builder::XmlMarkup.new(:indent => 2)
      s = b.div do
        b.p "Thank you for visiting FavColor; " +
          "please log in."
        b.form(:method => 'post', :action => '/done-login') do
          b.p do
            b.span "Email"
            b.br
            b.input(:id => 'email', :name => 'email')
          end
          b.p do
            b.span "Password"
            b.br
            b.input(:id => 'password', :type => 'password', :name => 'password')
          end
          b.p do
            b.input(:type => 'submit', :value => 'Go!')
          end
        end
        b.form(:method => 'get', :action => '/account-create') do
          b.p do
            b.span "First time here?"
            b.input(:type => 'submit', :value => 'Register!')
          end
        end
      end
      s.to_s
    end

    def self.dupe
      b = Builder::XmlMarkup.new(:indent => 2)
      s = b.form(:method => 'get', :action => '/account-create') do
        b.input(:type => 'submit', :value => 'OK')
      end
      s.to_s
    end

    def self.register
      b = Builder::XmlMarkup.new(:indent => 2)
      s = b.div do
        b.p "Thank you for your first visit to FavColor; " +
          "please tell us about yourself."
        b.form(:method => 'post', :action => '/new-login') do
          b.p do
            b.span "Email"
            b.br
            b.input(:id => 'email', :name => 'email')
          end
          b.p do
            b.span "Password"
            b.br
            b.input(:id => 'password', :type => 'password', :name => 'password')
          end
          b.p do
            b.span "What should I call you?"
            b.br
            b.input(:id => 'displayName', :name => 'displayName')
          end
          b.p do
            b.input(:type => 'submit', :value => 'Go!')
          end
        end 
        b.form(:method => 'get', :action => '/account-login') do
          b.p do
            b.span "Already have an account?"
            b.input(:type => 'submit', :value => 'Log in!')
          end
        end
      end
      s.to_s
    end

    def self.logout
      "<form method='post' action='/logout'>" +
        "<input type='submit' value='Log Out'/></form>"
    end

    def self.color(initial, greeting)
      b = Builder::XmlMarkup.new(:indent => 2)
      s = b.form(:method => 'post', :action => '/set-color') do
        b.p do
          b.p greeting
          b.input(:class =>
                  "color { "+
                  "pickerFaceColor:'transparent',pickerFace:3,pickerBorder:0," +
                  "pickerInsetColor:'black',pickerPosition:'top'" +
                  "}",
                  :value => initial,
                  :name => 'color')
        end
        b.p "If you don’t like this color, click on its " +
          "geek name just above, and pick a new one."
        b.p do
          b.input(:type => 'submit', :value => 'Set favorite color!')
        end
      end
      s.to_s
    end
  end
end        
