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

  def display_error_messages(content)
    if content.is_a?(Array)
      content.each { |message| yield(message) }
    elsif content.is_a?(String)
      yield(content)
    end
  end
end

######### Route Helpers ####################

def users_path
  File.expand_path('../users/users.yaml', __FILE__)
end

def load_users_from(users_path)
  YAML.load_file(users_path)
end

def errors_in_signup_credentials(username, password, password_confirmation)
  errors = []
  errors << errors_in_user_name(username)
  errors << errors_in_password(password, password_confirmation)
  errors.flatten
end

def errors_in_password(password, password_confirmation)
  errors = []
  errors << "Password can't be blank" if password.empty?
  errors << "Password muts have at least 6 characters." if password.size <= 5
  errors << "Password and confirmation do not match." if password != password_confirmation
  errors
end

def errors_in_user_name(username)
  errors = []
  users = YAML.load_file(users_path)
  errors << "Username can't be blank." if username.empty?
  errors << "Username already taken." if users.keys.include?(username)
  errors
end

def save_user!(username, password)
  users = load_users_from(users_path)
  hashed_password = BCrypt::Password.create(password)
  users[@username] = hashed_password.to_s
  File.open(users_path, 'w') do |f| 
    f.write YAML.dump(users)
  end
end

def redirect_non_admin_user_to(route)
  unless session[:username] == 'admin'
    session[:errors] = "Action only allowed to admin users"
    redirect route
  end
end

def redirect_logged_out_users_to(route)
  unless session[:username]
    session[:errors] = "You must be signed in to do that"
    redirect(route)
  end
end

def valid_credentials?(username, password)
  users = YAML.load_file(users_path)
  users[username] && BCrypt::Password.new(users[username]) == password
end

def errors_in_contact_infos(params)
  errors = []
  errors << errors_in_name(params[:first_name], params[:last_name])
  errors << errors_in_adress(params[:street], params[:number], params[:zipcode],
                             params[:country])
end

######### Routes ###########################

# Home page
get '/' do
  erb :index, layout: :layout
end

########## Contacts

# Display all contacts
get '/contacts' do
  redirect_logged_out_users_to('/')

  erb :contacts, layout: :layout
end

# Page for adding a new contact
get '/contacts/new' do
  erb :new_contact, layout: :layout
end

# Save a new contact
post '/contacts' do
  redirect_logged_out_users_to('/')

  errors = errors_in_contact_infos(params)
  if errors.empty?
    save_contact!(params)
    session[:success] = "Contact has been saved"
    redirect '/contacts'
  else
    status 422
    session[:errors] = errors
    erb :new_contact
  end
end

########## Categories

# Display categories
get '/categories' do
  redirect_logged_out_users_to('/')

  erb :categories, layout: :layout
end

########## Users

# Display all Users (only for admin)
get '/users' do
  #redirect_non_admin_user_to('/')
  @users = YAML.load_file(users_path)

  erb :users
end

# Sign up user
get '/users/new' do
  erb :new_user, layout: :layout
end

# Save user's credentials
post '/users' do
  @username = params[:username].strip
  password = params[:password]
  password_confirmation = params[:password_confirmation]

  errors = errors_in_signup_credentials(@username, password,
                                        password_confirmation)

  unless errors.empty?
    status 422
    session[:errors] = errors
    erb :new_user
  else
    save_user!(@username, password)
    
    session[:username] = @username
    session[:success] = "#{@username} has been successfully registred."
    redirect '/'
  end
end

# Delete user (only for admin)
post '/users/delete' do
  redirect_non_admin_user_to('/')
end

# Sign in
get '/users/signin' do
  erb :signin
end

# Sign user in
post '/users/signin' do
  username = params[:username]
  password = params[:password]

  if valid_credentials?(username, password)
    session[:username] = username
    session[:success] = "You've been signed in as '#{username}'"
    redirect '/'
  else
    status 422
    session[:errors] = "Invalid credentials"
    erb :signin
  end
end

# Sign out
post '/users/signout' do
  username = session.delete(:username)
  session[:success] = "Successfully signed out of #{username}'s session."
  redirect '/'
end
 
######### Default route if route does not exists
not_found do
  session[:errors] = "The page you requested does not exists."
  redirect '/'
end


