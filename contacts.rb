require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'bcrypt'
require 'yaml'
require 'tilt/erubis'
require 'pry' if development?

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

  def info_or_slash(info)
    info.empty? ? '/' : info
  end
end

######### Route Helpers ####################

######### Access and permissions controls

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

######### File paths

def users_path
  File.expand_path('../users/users.yaml', __FILE__)
end

def contacts_path
  File.expand_path('../data/contacts.yaml', __FILE__)
end

def next_id_path
  File.expand_path('../data/next_contact_index.yaml', __FILE__)
end

def load_users
  YAML.load_file(users_path)
end

def load_sorted_users
  load_users.sort_by { |name, _| name }
end

def load_contacts
  YAML.load_file(contacts_path)
end

def load_sorted_contacts
  contacts = load_contacts
  contacts.sort_by { |contact| contact[:last_name] }
end

def next_id
  YAML.load_file(next_id_path)[:next_id]
end

def categories_path
  File.expand_path('../data/categories.yaml', __FILE__)
end

def load_categories
  YAML.load_file(categories_path)
end

def load_contacts_by_category(category)
  contacts = load_contacts
  contacts.select { |contact| contact[:category] == category }
end

########## Validations

# User validations
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

def valid_credentials?(username, password)
  users = YAML.load_file(users_path)
  users[username] && BCrypt::Password.new(users[username]) == password
end

# Contacts validations
def errors_in_contact_infos(params)
  errors = []
  errors << errors_in_name(params[:first_name], params[:last_name])
  errors << errors_in_adress(params[:street], params[:number], params[:zipcode],
                             params[:city], params[:country])
  errors << errors_in_mail_or_phone(params[:phone_number], params[:mail_adress])
  errors << errors_in_birthdate(params[:birthdate])
  errors.flatten
end

def errors_in_name(first_name, last_name)
  errors = []
  errors << "First name can't be blank" if first_name.strip.empty?
  errors << "Last name can't be blank" if last_name.strip.empty?
  errors << "Name cannot include numbers" if [first_name, last_name].any? do |n|
    n.match?(/\d+/)
  end
  errors << "Name is too long (max 30)" if [first_name, last_name].any? do |n|
    n.size > 30
  end
  errors
end

def errors_in_adress(street, number, zip, city, country)
  errors = []
  errors << "City name cannot include numbers" if city.match?(/\d+/)
  errors << "Country name cannot inlcude numbers" if country.match?(/\d+/)
  errors << "City name is too long (max 40)" if city.size > 40
  errors << "Country name is too long (max 40)" if country.size > 40
  errors
end

def errors_in_mail_or_phone(phone, mail)
  errors = []
  errors << "Phone number can only have numbers" if phone.match?(/[a-zA-Z]+/)
  errors << "Invalid mail adress" unless valid_mail_adress?(mail) || mail.empty?
  errors
end

def errors_in_birthdate(birthdate)
  []
end

def valid_mail_adress?(mail)
  mail.match?(/\A\w+(\.?\w+?)*@\w+\.\w{2,4}\z/)
end

def errors_in_category_name(new_category)
  errors = []
  errors << "Catgeory cannot include numbers" if new_category.match?(/\d+/)
  errors << "Catgeory name is too long (max 40)" if new_category.size > 40
  errors
end

########## Storing actions

def save_user!(username, password)
  users = load_users
  hashed_password = BCrypt::Password.create(password)
  users[@username] = hashed_password.to_s
  File.open(users_path, 'w') do |f| 
    f.write YAML.dump(users)
  end
end

def format_contact_info(params)
  params.delete(:captures)
  infos = params.transform_values(&:strip).transform_keys(&:to_sym)
  
  [infos[:first_name], infos[:last_name], infos[:street], infos[:city],
   infos[:country], infos[:category]].each { |info| info.capitalize! }

  infos
end

def save_contact!(formatted_contact_infos)
  contacts = load_contacts
  id = next_id
  contacts << { id: id }.merge(formatted_contact_infos)
  File.open(contacts_path, 'w') { |f| f.write YAML.dump(contacts) }
  increment_contact_id(id, next_id_path)
end

def increment_contact_id(id, next_id_path)
  id += 1 
  File.open(next_id_path, 'w') { |f| f.write YAML.dump({ next_id: id }) }
end

def find_contact_by(id)
  contacts = load_contacts
  contacts.find { |contact| contact[:id] == id }
end

def update_contact!(updated_contact, id)
  contacts = load_contacts
  contact = find_contact_by(id)
  index_in_contacts_array = contacts.index(contact)
  contacts[index_in_contacts_array] = { id: id }.merge(updated_contact)
  File.open(contacts_path, 'w') { |f| f.write YAML.dump(contacts) }
end

def delete_contact_with_id!(id)
  contacts = load_contacts
  contact = find_contact_by(id)
  contacts.delete(contact)
  File.open(contacts_path, 'w') { |f| f.write YAML.dump(contacts) }
end

def save_category!(new_category)
  categories = load_categories
  categories << new_category.capitalize
  File.open(categories_path, 'w') { |f| f.write YAML.dump(categories) }
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
  @contacts = load_sorted_contacts

  erb :contacts, layout: :layout
end

# Page for adding a new contact
get '/contacts/new' do
  redirect_logged_out_users_to('/')

  erb :new_contact, layout: :layout
end

# Save a new contact
post '/contacts' do
  redirect_logged_out_users_to('/')

  errors = errors_in_contact_infos(params)
  if errors.empty?
    formatted_contact_infos = format_contact_info(params)
    save_contact!(formatted_contact_infos)
    session[:success] = "Contact has been saved"
    redirect '/contacts'
  else
    status 422
    session[:errors] = errors
    erb :new_contact
  end
end

# Display a contact's infos
get '/contacts/:id' do
  redirect_logged_out_users_to('/')

  id = params[:id].to_i
  @contact = find_contact_by(id)
  if @contact
    erb :show_contact, layout: :layout
  else
    session[:errors] = "There is no such contact"
    redirect '/contacts'
  end
end

# Page to edit a contact
get '/contacts/:id/edit' do
  redirect_logged_out_users_to('/')

  id = params[:id].to_i
  @contact = find_contact_by(id)
  if @contact
    erb :edit_contact, layout: :layout
  else
    session[:errors] = "There is no such contact"
    redirect '/contacts'
  end
end

# Update a contact
post '/contacts/:contact_id' do
  redirect_logged_out_users_to('/')

  id = params.delete(:contact_id).to_i

  errors = errors_in_contact_infos(params)
  if errors.empty?
    formatted_contact_infos = format_contact_info(params)
    update_contact!(formatted_contact_infos, id)
    session[:success] = "Contact has been updated"
    redirect "/contacts/#{id}"
  else
    status 422
    session[:errors] = errors
    erb :new_contact
  end
end

# Delete a contact
post '/contacts/:contact_id/delete' do
  redirect_logged_out_users_to('/')

  id = params[:contact_id].to_i
  delete_contact_with_id!(id)

  session[:success] = "Contact has been deleted"
  redirect '/contacts'
end

########## Categories

# Display all categories
get '/categories' do
  redirect_logged_out_users_to('/')
  @categories = load_categories

  erb :categories, layout: :layout
end

# Page to add a category
get '/categories/new' do
  redirect_logged_out_users_to('/')

  erb :new_category, layout: :layout
end

# Display all contacts of a category
get '/categories/:category_name' do
  redirect_logged_out_users_to('/')

  @category = params[:category_name]
  @contacts = load_contacts_by_category(@category)

  erb :show_category, layout: :layout
end

# Save a category
post '/categories' do
  redirect_logged_out_users_to('/')

  new_category = params[:category]
  errors = errors_in_category_name(new_category)
  if errors.empty?
    save_category!(new_category)
    session[:success] = "Category has been saved"
    redirect '/categories'
  else
    status 422
    session[:errors] = errors
    erb :new_category
  end
end

# Delete a category
post '/categories/:category_name/delete' do
  category = params[:category_name]

  categories = load_categories
  categories.delete(category)
  File.open(categories_path, 'w') { |f| f.write YAML.dump(categories) }
  session[:success] = "Category has been deleted"
  redirect '/categories'
end

########## Users

# Display all Users (only for admin)
get '/users' do
  redirect_non_admin_user_to('/')
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
