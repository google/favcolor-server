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
require './rp'

module Chooser

  TEXT_HTML = { 'Content-type' => 'text/html; charset=utf-8' }
  APPLICATION_JSON = { 'Content-type' => 'application/json' }

  class Chooser < Sinatra::Base
    enable :sessions

    ### App code

    # Home page
    get '/' do

      # active session?
      email = session[:logged_in]
      if email
        # Session is active, branch to favorite-color app
        account = database.find_account email
        s = Color.chooser account
        [200, TEXT_HTML, s]

      else
        # No session, they have to log in
        redirect '/account-login'
      end
    end

    # Only for our native Android app; a POST so they can send along
    #  the secret ID Token
    #
    post '/get-color' do
      params = Body::parse_json request
      params = RP::from_id_token params['id-token']
      email = params['email']
      if email
        account = database.find_account email
        if account
          fields = ['email', 'displayName', 'photoUrl', 'color']
          fields = fields.select { |field| is_useful?(account[field]) }
          fields = fields.map { |field| "\"#{field}\":\"#{account[field]}\"" }
          json = "{" + fields.join(',') + "}"
          [200, APPLICATION_JSON, json]
        else
          [404, nil, nil]
        end
      else
        [404, nil, nil]
      end
    end

    # Save favorite color, after they've picked it
    post '/set-color' do
      id_token = params['id_token']
      if id_token
        # coming in from Android client
        jwt = RP::from_id_token id_token
        email = jwt['email']
      else
        email = session[:logged_in]
      end

      if email && database.find_account(email)
        account = database.find_account email
        account['color'] = params['color']
        database.save_account account
        if id_token
          [200, nil, nil]
        else
          redirect '/'
        end
      else
        [404, nil, nil]
      end
    end

    ### Identity/Authentication/Authorization code

    # Come here to log in
    get '/account-login' do
      p = Page.new('Login', ac_dot_js(request, RP::providers))
      p.h2! 'Welcome to FavColor!'
      p.payload! Forms.login(request)
      [200, TEXT_HTML, p.to_s]
    end

    # Come here to register a new account
    get '/account-create' do
      p = Page.new('First-time Login', ac_dot_js(request))
      p.h2! 'Welcome to FavColor!'
      p.payload! Forms.register(request)
      [200, TEXT_HTML, p.to_s]
    end

    # Google redirect with #fragment if we're just logging in
    get '/gauth-login-redirect' do
      script = "<script>\n" +
        Page::parse_hash_script +
        "var h = window.location.hash.slice(1);\n" +
        "window.location = '/gauth-login-2?' + h;\n" +
        "</script>"
      p = Page.new('Redirecting', script)
      p.h2! 'Redirecting' # user should't see this
      [200, TEXT_HTML, p.to_s]
    end

    get '/gauth-login-2' do
      email = database.get_state params['state']
      session[:logged_in] = email
      redirect '/'
    end

    # Google redirect with &params if we're fetching data
    get '/gauth-fetch-redirect' do
      if params['error']
        auth_failed params['error_description']
      else
        auth_succeeded(:google, params)
      end
    end


    # Facebook redirects here
    get '/fbauth-redirect' do
      if params['error']
        auth_failed params['error_description']
      else
        auth_succeeded(:facebook, params)
      end
    end

    # Microsoft Live redirects here
    get '/liveauth-redirect' do
      if params['error']
        auth_failed params['error_description']
      else
        auth_succeeded(:live, params)
      end
    end

    # ac.js comes here to see if we know this person
    post '/account-status' do
      params = Body::parse_form(request)

      # speculatively save ac.js fields into a new account IF there's an IDP
      email = params['email']
      registered = database.find_account email
      if params['providerId']
        update_account params
      end

      state = make_state
      auth_uri = RP::auth_uri(params, request, state)
      
      if auth_uri
        database.set_state(state, email)
        [ 200, APPLICATION_JSON, "{ \"authUri\" : \"#{auth_uri}\" }" ]
      else
        account = database.find_account email
        [ 200, APPLICATION_JSON,
          '{"registered":' + ((registered) ? 'true' : 'false') + '}']
      end
    end

    # Kill session on logout
    post '/logout' do
      session[:logged_in] = nil
      redirect '/'
    end

    # Creation form submission
    post '/new-login' do
      params = Body::parse_form request
      email = params['email']
      provider = params['providerId']

      state = is_useful?(email) ? make_state : nil

      if provider

        # provider selected
        if is_useful? email

          # got an email too; if we have an account with the same
          #  provider, use that to help redirect
          database.set_state(state, email)
          account = database.find_account email
          if account && account['providerId'].eql?(provider)
            params = account
          end
        end

        # redirect to provider
        redirect RP::auth_uri(params, request, state)
      else
        
        # no provider
        # They have to give us at least an email and password
        if !(is_useful?(email) && is_useful?(params['password']))
          redirect back

        else
          # got an email and password

          # is there already an account?
          if database.find_account(email)
            redirect '/dupe'

          else
            # We really have a new account, persist it & start session
            account = Account.new(params)
            database.save_account account
            session[:logged_in] = email
            update_ac_js account
          end
        end
      end
    end

    # tried to register an account with an existing email address
    get '/dupe' do
      p = Page.new "Duplicate account!"
      p.h2! "Sorry, that email is taken."
      p.payload! Forms.dupe
      [200, TEXT_HTML, p.to_s]
    end

    # login form submission
    post '/done-login' do
      params = Body::parse_form request
      email = params['email']
      provider = params['providerId']

      state = is_useful?(email) ? make_state : nil

      if provider

        # provider selected
        if is_useful? email

          # got an email too; if we have an account with the same
          #  provider, use that to help redirect
          session[state] = email
          account = database.find_account email
          if account && account['providerId'].eql?(provider)
            params = account
          end
        end

        # redirect to provider
        session[make_state] = email if is_useful? email
        s = RP::auth_uri(params, request, state)
        redirect s
      else
        # no provider selected
        if !is_useful?(email)

          # no email either, can't help them
          redirect back
        else
          
          # got an email
          account = database.find_account email
          if account == nil

            # no existing account, try to sign them up
            redirect '/account-create'

          else
            # we have an account for that email
            if account['providerId']

              # the account has a provider, use it
              session[state] = email
              redirect RP::auth_uri(params, request, state)

            else

              # no provider, have to use password
              if !is_useful?(params['password'])

                # no password either, can't help them
                redirect back
                
              else
                # email & password supplied
                if account.check_password(params['password'])

                  # success! Establish a session
                  session[:logged_in] = email
                  update_ac_js account
                else
                  # wrong password or email
                  auth_failed 'Incorrect email or password.'
                end
              end
            end
          end
        end
      end
    end

    # will redirect back to '/'
    def update_ac_js account
      fields = "accountchooser.CONFIG.storeAccount = {\n"
      ['email', 'displayName', 'photoUrl', 'providerId'].each do |name|
        field = account[name]
        fields += "#{name}: \"#{field}\",\n" if is_useful?(field)
      end
      fields += '};'
      p = Page.new('Update ac.js', ac_dot_js(request, fields))
      p.h2! 'Updating AccountChooser' # user shouldn't see this
      [200, TEXT_HTML, p.to_s]
    end

    MARKETING_HEADERS = {
      'Content-type' => 'text/html; charset=utf-8',
      "Access-Control-Allow-Origin" => "*",
      "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
      "Access-Control-Max-Age" => "86400"
    }
    MARKETING_TEXT = "<img src=\"https://favcolor.net/g60.png\" " +
      "style=\"float:left;width: 150px;\"/>\n" +
      "<p style='margin-left: 160px;'>" +
      "FavColor — We know your favorite!</p>"

    get '/login-marketing' do
      [ 200, MARKETING_HEADERS, MARKETING_TEXT ]
    end

    ### Utility code

    private

    def auth_failed problem
      p = Page.new 'Authorization failed'
      p.h2! 'Authorization failed'
      p.payload! "<p>#{problem} [<a href='/'>Try again</a>]</p>"
      [403, TEXT_HTML, p.to_s]
    end

    def auth_succeeded(provider, params)
      code = params['code']
      account = Account.new(RP::fetch_account(provider, code, request))
      account = update_account account
      session[:logged_in] = account['email']

      # we want to update accountchooser with whoever they logged in with,
      #  not who we might think their primary IDP is.
      account = account.clone
      account['providerId'] = RP::provider_name provider
      update_ac_js account
    end

    def update_account incoming
      email = incoming['email']

      existing_account = database.find_account email
      updated = false
      if existing_account
        ['displayName', 'photoUrl', 'providerId'].each do |field|
          # only update if old one not there
          if incoming[field] && !existing_account[field]
            updated = true
            existing_account[field] = incoming[field]
          end
        end
        incoming = existing_account
      else
        updated = true
      end

      if updated
        if !incoming.kind_of? Account
          incoming = Account.new(incoming)
        end
        database.save_account incoming
      end
      incoming
    end

    AC_JS = '<script type="text/javascript" ' +
      'src="https://www.accountchooser.com/ac.js" ></script>' + "\n" +
      "<script type='text/javascript'>\n" +
      "accountchooser.CONFIG.uiConfig = {\n  title: \"Log in to FavColor\",\n"

    def ac_dot_js(req, extras = '')
      branding = "  branding: \"https://#{req.host}/" +
        "login-marketing\"\n};\n"
      AC_JS + branding + extras + "\n</script>"
    end

    def logger
      @logger = Logger.new(STDOUT) unless @logger
      @logger
    end

    def database
      @database = Database.new unless @database
      @database
    end

    def is_useful? object
      (object != nil) && !object.empty?
    end

    def make_state
      rand(10 ** 9).to_s + rand(10 ** 9).to_s
    end
  end
end

