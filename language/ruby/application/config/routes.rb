Rails.application.routes.draw do
  get '/health', to: 'commerce#health'
  post '/assistant', to: 'commerce#assistant'
end
