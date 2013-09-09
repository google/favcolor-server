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
# Tim, why can't you just use one of the excellent Ruby templating packages?!
require 'builder'
require 'json'
require 'net/http'

module Chooser
  class Persona
    
    def self.sign_in(email)
      b = Builder::XmlMarkup.new(:indent => 2)
      head = b.head do 
        b.title "Sign in with Persona"
        b.link(:rel => 'stylesheet', :type => 'text/css', 
               :href => '/chooser.css')
        b.link(:rel => 'stylesheet', :type => 'text/css', 
               :href => '/bootstrap/css/bootstrap.min.css')
        b.script(persona_script(email), :type => 'text/javascript')
      end

      body = b.body do
        b.div(:class => 'row-fluid', :id => 'container') do
          b.div(:class => 'span3', :id => 'left') do
            b.img(:src => 'g60s.png'); b.br
            b.img(:src => 'r96s.png'); b.br
            b.img(:src => 'b88s.png')
          end
          b.div(:class => 'span8') do
            b.h3 "Persona Sign-in"
            b.p do
              b.input(:id => 'email', :name => 'email',
                      :placeholder => 'email', :class => 'input-medium')
              b.button(:id => 'sign-in-button', :class => 'btn') do
                b.span "Sign in with Persona" 
              end
            end
            b.p "You shouldn’t have to do this."
            b.script("/* */", :src => '/bootstrap/js/bootstrap.min.js')
            b.script("/* */", :src => 'https://login.persona.org/include.js')
          end
        end
      end
      "<html>\n" + head + "\n" + body + "\n" + "</html>"
    end

    SCRIPT_BASE = <<EOFEOF
    var signinLink = document.getElementById('sign-in-button');
    if (signinLink) {
      signinLink.onclick = function() { 
        var email = document.getElementById('email').value;
          /* loggedInUser: email, */
        navigator.id.watch( {
               onlogin: verifyAssertion,
              onlogout: onlo
        } );
        navigator.id.request(); };
    }

    function simpleXhrSentinel(xhr) {
      return function() {
        if (xhr.readyState == 4) {
          if (xhr.status == 200){
            // reload page to reflect new login state
            window.location = '/persona-succeeded'
          } else {
            navigator.id.logout();
            alert("XMLHttpRequest error: " + xhr.status); 
          } 
        }
      }
    }

    function verifyAssertion(assertion) {
      var xhr = new XMLHttpRequest();
      xhr.open("POST", "/persona-assertion", true);

      // see http://www.openjs.com/articles/ajax_xmlhttp_using_post.php
      var param = "assert=" + assertion;
      xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
      xhr.send(param); // for verification by your backend

      xhr.onreadystatechange = simpleXhrSentinel(xhr); 
    }

    function onlo() {
      // Your backend must return HTTP status code 200 to indicate successful
      // sign out (usually the resetting of one or more session variables) and
      // it must arrange for the binding of currentUser to 'null' when the page
      // is reloaded
      var xhr = new XMLHttpRequest();
      xhr.open("GET", "/xhr/sign-out", true);
      xhr.send(null);
      xhr.onreadystatechange = simpleXhrSentinel(xhr); 
    }
    function onlo() {
      alert("Logout!")
    }
EOFEOF

    def self.verify_assertion(assertion)
      request = JSON.generate(
        "assertion" => assertion,
        "audience" => "https://favcolor.net:443/")
      puts "REQUEST: #{request}"

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
        puts "BODY #{response.body}"
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

    def self.persona_script(email)
      "\n" + SCRIPT_BASE.gsub('_EMAIL_', email)
    end

    def to_s
    end
  end
end
