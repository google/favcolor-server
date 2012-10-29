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

    def self.login request
      b = Builder::XmlMarkup.new(:indent => 2)
      s = b.div do
        b.form(:method => 'post', :action => '/done-login') do
          b.div(:class => 'row') do
            b.legend "Thank you for visiting; please log in."
          end
          b.div(:class => 'row') do
            b.div(:class => 'span12') do
              email(b)
            end
          end
          b.div(:class => 'row') do
            b.div(:class => 'span12') do
              password(b)
              b.div(:style => 'display: inline; position:relative;top: 5px;') do
                b.span "  Or, use one of "
                b.button(:name => 'providerId', :value => 'google.com') do
                  b.img(:src => 'G.png', :alt => 'log in with Google',
                        :style => 'height: 1.2em')
                end
                b.button(:name => 'providerId', :value => 'live.com') do
                  b.img(:src => 'Live.png', :alt => 'log in with Live.com',
                        :style => 'height: 1.2em')
                end
                b.button(:name => 'providerId', :value => 'facebook.com') do
                  b.img(:src => 'fb.png', :alt => 'log in with Facebook',
                        :style => 'height: 1.2em')
                end

                b.hr
              end
            end
          end
        end
        b.div(:class => 'row') do
          b.div(:class => 'span12') do
            b.form(:method => 'get', :action => '/account-create') do
              b.span "First time here?"
              b.input(:type => 'submit', :value => 'Register!')
            end
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

    def self.blast request
      b = Builder::XmlMarkup.new(:indent => 2)
      s = b.div do
        b.form(:method => 'post', :action => '/do-blast') do
          b.p do
            b.span "email"
            b.br
            email(b)
          end
          b.p do
            b.span "displayName"
            b.br
            b.input(:id => 'displayName', :name => 'displayName')
          end
          b.p do
            b.span "photoUrl"
            b.br
            b.input(:id => 'photoUrl', :name => 'photoUrl')
          end
          b.p do
            b.span "providerId"
            b.br
            b.input(:id => 'providerId', :name => 'providerId')
          end
          b.p do
            b.input(:type => 'submit', :value => 'Go!')
          end
        end
      end
      s.to_s
    end

    def self.register request
      b = Builder::XmlMarkup.new(:indent => 2)
      s = b.div do
        b.form(:method => 'post', :action => '/new-login') do
          b.div(:class => 'row') do
            b.legend "Thank you for your first visit to FavColor; " +
              "please tell us about yourself."
          end
          b.div(:class => 'row') do
            b.div(:class => 'span12') do
              email(b)
            end
          end
          b.div(:class => 'row') do
            b.div(:class => 'span12') do
              b.span "What should I call you?"
              b.br
              b.input(:id => 'displayName', :name => 'displayName')
            end
          end
          b.div(:class => 'row') do
            b.div(:class => 'span12') do
              b.span "URL of a picture?"
              b.br
              b.input(:id => 'photoUrl', :name => 'photoUrl')
            end
          end
          b.div(:class => 'row') do
            b.div(:class => 'span12') do
              b.p do
                password(b)
                b.div(:style => 'display: inline; position:relative;top: 5px;') do
                  b.span "  Or, use one of "
                  b.button(:name => 'providerId', :value => 'google.com') do
                    b.img(:src => 'G.png', :alt => 'log in with Google',
                          :style => 'height: 1.2em')
                  end
                  b.button(:name => 'providerId', :value => 'live.com') do
                    b.img(:src => 'Live.png', :alt => 'log in with Live.com',
                          :style => 'height: 1.2em')
                  end
                  b.button(:name => 'providerId', :value => 'facebook.com') do
                  b.img(:src => 'fb.png', :alt => 'log in with Facebook',
                        :style => 'height: 1.2em')
                  end
                  
                  b.hr
                end
              end
            end
          end
        end 
        b.div(:class => 'row') do
          b.div(:class => 'span12') do
            b.form(:method => 'get', :action => '/account-login') do
              b.span "Already registered?"
              b.input(:type => 'submit', :value => 'Log in!')
            end
          end
        end
      end
      s.to_s
    end

    CHOOSER_CONTROL = "color { " +
                    "pickerFaceColor:'transparent'," +
                    "pickerFace:3,pickerBorder:0," +
                    "pickerInsetColor:'black',pickerPosition:'top'" +
                    "}"


    def self.color(initial, greeting)
      b = Builder::XmlMarkup.new(:indent => 2)
      s = b.div do
        b.div(:class => 'row') do
          b.div(:class => 'span9',
                :style => "border: 10px solid ##{initial};") do
            b.div(:class => 'row') do
              b.div(:class => 'offset1 span10') do
                b.form(:method => 'post', :action => '/set-color') do
                  b.p ""
                  b.p greeting
                  b.input(:class => CHOOSER_CONTROL,
                          :value => initial,
                          :name => 'color')
                  b.p "If you don’t like this color, click on its " +
                    "geek name just above, and pick a new one."
                  b.p do
                    b.input(:type => 'submit', :value => 'Set favorite color!')
                  end
                end
              end
            end
          end
        end
        b.div(:class => 'row') do
          b.div(:class => 'span8') do
            b.p
            b.form(:method => 'post', :action => '/logout') do
              b.input(:type => 'submit', :value => 'Log Out')
            end
          end
        end
      end         
      s.to_s
    end

    def self.password b
      b.div(:class => 'input-append', :style => 'display: inline;') do
        b.input(:id => 'password', :type => 'password',
                :class => 'input-medium',
                :name => 'password', :placeholder => 'password')
        b.button(:class => 'btn', :type => 'Submit', :value => 'Go!') do
          b.span "Go!"
        end
      end
    end
    def self.email b
      b.input(:id => 'email', :name => 'email',
              :placeholder => 'email', :class => 'input-medium')
    end

  end
end        
