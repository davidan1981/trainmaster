Trainmaster::Engine.routes.draw do
  resources :sessions
  match 'sessions(/:id)' => 'sessions#options', via: [:options]

  resources :users
  match 'users(/:id)' => 'users#options', via: [:options]

  get 'auth/:provider/callback', to: 'sessions#create'
  # get 'auth/failure', to: 'session#create'
end
