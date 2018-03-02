require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'bcrypt'
require 'yaml'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

# Home page
get '/' do
  erb :index, layout: :layout
end


# Display all contacts
get '/contacts' do

end

# Add a new contact page
get '/contacts/new' do

end

# Display categories
get '/categories' do
  
end

# Default route if route does not exists
not_found do
  session[:message] = "The page you requested does not exists."
  redirect '/'
end


