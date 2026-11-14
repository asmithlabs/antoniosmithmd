Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "pages#home"
  get "projects" => "pages#projects"
  get "search" => "search#index"
  resources :posts, only: %i[index show], path: "blog" do
    resources :comments, only: :create do
      post :vote, on: :member
    end
  end
  get "blog/category/:category" => "posts#index", as: :category
  get "blog/tag/:tag" => "posts#index", as: :tag
  get "feed.xml" => "posts#feed", as: :feed, defaults: { format: :xml }
  get "sitemap.xml" => "seo#sitemap", defaults: { format: :xml }
  get "robots.txt" => "seo#robots", defaults: { format: :text }
  namespace :api do
    namespace :v1 do
      resources :posts, only: %i[index show update destroy]
      resources :comments, only: %i[index update]
      resources :references, only: :index
    end
  end
  namespace :admin do
    resources :api_tokens, only: %i[index create destroy]
    resources :references, only: :index do
      post :sync, on: :collection
    end
    root "posts#index"
    get "login" => "sessions#new"
    post "login" => "sessions#create"
    get  "login/verify" => "sessions#mfa", as: :mfa
    post "login/passkey/options" => "sessions#passkey_options", as: :passkey_login_options
    post "login/passkey" => "sessions#passkey", as: :passkey_login
    post "login/duo" => "sessions#duo_start", as: :duo_start
    get  "login/duo/callback" => "sessions#duo_callback", as: :duo_callback
    delete "logout" => "sessions#destroy"
    resources :passkeys, only: %i[index create destroy] do
      post :options, on: :collection
    end
    resources :posts, except: :show do
      resources :revisions, only: %i[index show] do
        post :restore, on: :member
      end
    end
    resources :comments, only: %i[index update destroy]
  end
end
