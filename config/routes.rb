require 'sidekiq/web'

Feedbin::Application.routes.draw do

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  root to: 'site#index'

  mount Sidekiq::Web, at: '/sidekiq'
  mount StripeEvent::Engine, at: '/stripe'

  get :health_check, to: proc {|env| [200, {}, ["OK"]] }
  get :version, to: proc {|env| [200, {}, [ENV["ETAG_VERSION_ID"]]] }

  get :home, to: 'site#home'
  get :apps, to: 'site#apps'

  # Firefox OS manifest
  get :manifest, to: 'site#manifest'

  post '/emails' => 'emails#create'

  match '/404', to: 'errors#not_found', via: :all
  get '/starred/:starred_token', to: 'starred_entries#index', as: 'starred'
  post '/starred/export', to: 'starred_entries#export'
  get '/favicons/:hash', to: 'favicons#index', as: 'favicons'


  get    :signup,         to: 'users#new',           as: 'signup'
  get    :login,          to: 'sessions#new',        as: 'login'
  get    :privacy_policy, to: 'site#privacy_policy', as: 'privacy_policy'
  delete :logout,         to: 'sessions#destroy',    as: 'logout'

  # Apple Push

  # When a user allows permission to receive push notifications
  post 'apple_push_notifications/:version/pushPackages/:website_push_id', as: :apple_push_notifications_package, to: 'apple_push_notifications#create', website_push_id: /.*/

  # POST When users first grant permission, or later change their permission
  # levels for your website
  post 'apple_push_notifications/:version/devices/:device_token/registrations/:website_push_id', as: :apple_push_notifications_update, to: 'apple_push_notifications#update', website_push_id: /.*/

  # DELETE If a user removes permission of a website in Safari preferences, a
  # DELETE request is sent
  delete 'apple_push_notifications/:version/devices/:device_token/registrations/:website_push_id', as: :apple_push_notifications_delete, to: 'apple_push_notifications#delete', website_push_id: /.*/

  # Error log
  post 'apple_push_notifications/:version/log', as: :apple_push_notifications_log, to: 'apple_push_notifications#log'

  resources :tags,           only: [:index, :show, :update, :destroy]
  resources :billing_events, only: [:show]
  resources :imports
  resources :sessions
  resources :password_resets
  resources :sharing_services, path: 'settings/sharing', only: [:index, :create, :update, :destroy]
  resources :actions, path: 'settings/actions', only: [:index, :create, :new, :update, :destroy, :edit]
  resources :saved_searches

  resources :supported_sharing_services, only: [:create, :destroy, :update] do
    member do
      get :oauth2_pocket_request
      get :oauth2_pocket_response
      get :oauth_response
      get :autocomplete
      post :xauth_request
      match 'share/:entry_id', to: 'supported_sharing_services#share', as: :share, via: [:get, :post]
    end
  end

  resources :subscriptions,  only: [:index, :create, :destroy] do
    collection do
      patch :update_multiple
      delete :destroy_all
    end
    member do
      delete :settings_destroy
    end
  end

  resources :users, id: /.*/ do
    member do
      patch :settings_update, controller: :settings
      patch :view_settings_update, controller: :settings
    end
  end

  resources :feeds, only: [:index, :edit, :create, :update] do
    patch :rename
    resources :entries, only: [:index], controller: :feeds_entries
    collection do
      get :view_unread
      get :view_all
      get :view_starred
      get :auto_update
      get :update_styles
    end
    member do
      match :push, via: [:post, :get]
      post :toggle_updates
      post :toggle_muted
    end
  end

  resources :entries, only: [:show, :index] do
    member do
      post :content
      post :unread_entries, to: 'unread_entries#update'
      post :starred_entries, to: 'starred_entries#update'
      post :mark_as_read, to: 'entries#mark_as_read'
      post :recently_read, to: 'recently_read_entries#create'
      get :push_view
      get :diff
    end
    collection do
      get :starred
      get :unread
      get :preload
      get :search
      get :autocomplete_search
      get :recently_read, to: 'recently_read_entries#index'
      get :updated, to: 'updated_entries#index'
      post :mark_all_as_read
      post :mark_direction_as_read
    end
  end

  get :settings, to: 'settings#settings'
  namespace :settings do
    get :account
    get :billing
    get :import_export
    get :feeds
    get :help
    get :appearance
    post :update_credit_card
    post :mark_favicon_complete
    post :update_plan
    post :font
    post :theme
    post :font_increase
    post :font_decrease
    post :entry_width
  end

  constraints subdomain: 'api' do
    namespace :api, path: nil do
      namespace :v1 do
        match '*path', to: 'api#gone', via: :all
      end
    end
  end

  constraints subdomain: 'api' do
    namespace :api, path: nil do
      namespace :v2 do

        resources :feeds, only: [:show] do
          resources :entries, only: [:index, :show], controller: :feeds_entries
        end

        resources :entry_counts, only: [] do
          collection do
            get :post_frequency
          end
        end

        resources :actions, only: [:index, :create, :update] do
          member do
            get :results
          end
        end

        resources :devices,               only: [:create] do
          collection do
            get :test
          end
        end

        resources :subscriptions,         only: [:index, :show, :create, :destroy, :update]
        resources :favicons,              only: [:index]
        resources :tags,                  only: [:index]
        resources :taggings,              only: [:index, :show, :create, :destroy]
        resources :entries,               only: [:index, :show]
        resources :recently_read_entries, only: [:index, :create]

        get :authentication, to: 'authentication#index'

        post "subscriptions/:id/update", to: 'subscriptions#update'

        resources :unread_entries, only: [:index, :show, :create]
        delete 'unread_entries', to: 'unread_entries#destroy'
        put 'unread_entries', to: 'unread_entries#create'
        post 'unread_entries/delete', to: 'unread_entries#destroy'

        resources :starred_entries, only: [:index, :show, :create]
        delete 'starred_entries', to: 'starred_entries#destroy'
        put 'starred_entries', to: 'starred_entries#create'
        post 'starred_entries/delete', to: 'starred_entries#destroy'

        resources :updated_entries, only: [:index]
        delete 'updated_entries', to: 'updated_entries#destroy'
        post 'updated_entries/delete', to: 'updated_entries#destroy'

        resources :saved_searches,  only: [:index, :show, :create, :destroy, :update]
        post "saved_searches/:id/update", to: 'saved_searches#update'
      end
    end
  end

end
