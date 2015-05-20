# helper
require 'jwt'
module CreditCardAPIHelper
  # def login(user)
  #   session[:user_id] = user.id
  #   redirect '/'
  # end

  def login_user(user)
    payload = {user_id: user.id}
    token = JWT.encode payload, ENV['MSG_KEY'], 'HS256'
    session[:auth_token] = token
    redirect '/'
  end

  def find_user_by_token(token)
    return nil unless token
    decoded_token = JWT.decode token, ENV['MSG_KEY'], true
    payload = decoded_token.first
    logger.info "PAYLOAD: #{payload}"
    User.find_by_id(payload["user_id"])
  end
end
