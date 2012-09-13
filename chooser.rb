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
require 'sinatra'
require './body'
require './database'
require './forms'
require './color'

module Chooser

  class Chooser < Sinatra::Base
    enable :sessions

    ### App code

    # Home page
    get '/' do

      # active session?
      email = session[:logged_in]
      if email
        # Session is active, branch to favorite-color app
        account = database.find email
        s = Color.chooser account
        [200, { 'Content-type' => 'text/html' }, s]

      else
        # No session, they have to log in
        redirect '/account-login'
      end
    end
    
    # Save favorite color, after they've picked it
    post '/set-color' do
      account = database.find session[:logged_in]
      params = Body::parse_body request
      account['color'] = params['color']
      database.save account
      redirect '/'
    end

    ### Identity/Authentication/Authorization code

    # Come here to log in
    get '/account-login' do
      p = Page.new 'Login'
      p.h2! 'Welcome to FavColor!'
      p.payload! Forms.login
      [200, { 'Content-type' => 'text/html' }, p.to_s]
    end

    # Come here to register a new account
    get '/account-create' do
      p = Page.new 'First-time Login'
      p.h2! 'Welcome to FavColor!'
      p.payload! Forms.register
      [200, { 'Content-type' => 'text/html' }, p.to_s]
    end

    # Kill session on logout
    post '/logout' do
      session[:logged_in] = nil
      redirect '/'
    end

    # Come here after registering, to save a new account
    post '/new-login' do
      params = Body::parse_body request
      email = params['email']

      # is there already an account?
      if database.find(email)
        redirect '/dupe'

      else
        # We really have a new account, persist it & start session
        account = Account.new(params)
        database.save account
        session[:logged_in] = email
        redirect '/'
      end
    end

    # tried to register an account with an existing email address
    get '/dupe' do
      p = Page.new "Duplicate account!"
      p.h2! "Sorry, that email is taken."
      p.payload! Forms.dupe
      [200, { 'Content-type' => 'text/html' }, p.to_s]
    end

    # attempt to log in an existing account
    post '/done-login' do
      params = Body::parse_body request
      email = params['email']
      account = database.find email

      if account
        # we know this person, check the password
        if account.check_password(params['password'])

          # success! Establish a session
          session[:logged_in] = email
          redirect '/'

        else
          # wrong password or email
          redirect '/account-login'
        end

      else
        # Apparently a new user
        redirect '/account-create'
      end
    end

    ### Utility code

    private

    def logger
      @logger = Logger.new(STDOUT) unless @logger
      @logger
    end

    def database
      @database = Database.new unless @database
      @database
    end
  end
end

