require 'json'
require 'sinatra'
require_relative 'model/credit_card.rb'
require_relative 'model/user.rb'
require_relative 'helpers/credit_card_api_helper.rb'
require 'rack-flash'
require 'config_env'


# credit card api service
class CreditCardAPI < Sinatra::Base
  include CreditCardAPIHelper

  # use Rack::Session::Cookie
  enable :logging

  configure :development, :test do
    # require 'config_env'
    ConfigEnv.path_to_config("#{__dir__}/config/config_env.rb")
  end

  configure do
    use Rack::Session::Cookie, secret: ENV['MSG_KEY']
    use Rack::Flash, :sweep => true
  end

  # before do
  #   @current_user = session[:user_id] ? User.find_by_id(session[:user_id]): nil
  # end

  before do
    @current_user = find_user_by_token(session[:auth_token])
  end

  get '/' do
    haml :index
  end

  get '/api/v1/users/sign_up/?' do
    haml :sign_up
  end

  post '/logout' do
    session[:auth_token] = nil
    flash[:notice] = "You have logged out"
    redirect '/'
  end

  post '/register' do
    registration =
      Registration.new(params[:username], params[:email], params[:password])
    unless (registration.complete?)
      flash[:error] = "Please fill in all the fields"
      redirect '/register'
      halt
    end
  end

  post '/api/v1/users/sign_up/?' do
    logger.info('Sign Up')
    password = params[:password]
    password_confirm = params[:password_confirm]
    begin
      if password == password_confirm
        new_user = User.new(params.except(:password_confirm.to_s))
        new_user.password = password
        new_user.save! ? login_user(new_user) : fail('New user creation failed')
      else
        fail 'Passwords do not match'
      end
    rescue => exception
      logger.error(exception)
      redirect '/api/v1/users/sign_up/'
    end
  end

  get '/api/v1/users/sign_in/?' do
    haml :sign_in
  end

  post '/api/v1/users/sign_in/?' do
    username = params[:username]
    password = params[:password]
    user = User.authenticate!(username, password)
    user ? login_user(user) : redirect('/api/v1/users/sign_in/')
  end

  post '/api/v1/users/sign_out/?' do
    session[:user_id] = nil
    redirect '/'
  end

  get '/api/v1/credit_card/validate/?' do
    number = params[:card_number]
    halt 400 unless number
    card = CreditCard.new
    card.number = number
    {
      card: number,
      validated: card.validate_checksum
    }.to_json
  end

  post '/api/v1/credit_card/?' do
    request_json = request.body.read
    unless request_json.empty?
      begin
        obj = JSON.parse(request_json)
        card = CreditCard.new(
          expiration_date: obj['expiration_date'],
          owner: obj['owner'],
          credit_network: obj['credit_network']
        )
        card.number = obj['number'].chomp
        if card.validate_checksum && card.save
          status 201
          body({
            status: 201,
            message: 'Created'
          }.to_json)
        else
          status 410
          body({
            status: 410,
            message: 'Gone'
          }.to_json)
        end
      rescue
        halt 400, {
          status: 400,
          message: 'Bad Request'
        }.to_json
      end
    end
  end

  get '/api/v1/credit_card/all/?' do
    begin
      CreditCard.all.map(&:to_hash).to_json
    rescue
      halt 500
    end
  end
end
