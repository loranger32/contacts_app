require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'bcrypt'
require 'yaml'
require 'tilt/erubis'

######### Configuration ####################

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

######### View Helpers #####################

helpers do
  def display_user_status(session)
    if session[:username]
      @username = session[:username]
      erb :logged_in_infos
    else
      erb :logged_out_infos
    end
  end
end

######### Route Helpers ####################




# Home page
get '/' do
  erb :index, layout: :layout
end


# Display all contacts
get '/contacts' do
  erb :contacts, layout: :layout
end

# Add a new contact page
get '/contacts/new' do
  erb :new_contact, layout: :layout
end

# Display categories
get '/categories' do
  erb :categories, layout: :layout
end

# Default route if route does not exists
not_found do
  session[:error] = "The page you requested does not exists."
  redirect '/'
end


