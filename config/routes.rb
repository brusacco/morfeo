# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users
  get 'topic/show'
  get 'tag/show'
  get 'entry/show'
  get 'entry/search', as: 'entry_search'
  get 'entry/popular', as: 'popular_entries'
  get 'entry/twitter', as: 'twitter_entries'
  get 'entry/commented', as: 'commented_entries'
  get 'entry/week', as: 'week_entries'
  get 'entry/similar', to: 'entry#similar', as: 'similar_entries'
  get '/site/:id', to: 'site#show', as: 'site'

  get '/tag/search', to: 'tag#search', as: 'search_tag'
  get '/tag/:id', to: 'tag#show', as: 'tag'
  get '/tag/:id/report', to: 'tag#report', as: 'report'
  get '/tag/:id/comments', to: 'tag#comments', as: 'tag_comments'

  get '/topic/:id', to: 'topic#show', as: 'topic'
  get '/topic/:id/history', to: 'topic#history', as: 'topic_history'
  get '/topic/:id/comments', to: 'topic#comments', as: 'topic_comments'

  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  get 'home/index'
  get 'home/check'
  post 'deploy', to: 'home#deploy'
  root 'home#index'

  # ChatGPT API definition routes
  namespace :api do
    namespace :v1 do
      get 'entries/show', to: 'entries#show', as: 'show_entry'
      get 'entries/popular', to: 'entries#popular', as: 'popular_entries'
      get 'entries/latest', to: 'entries#latest', as: 'latest_entries'
      get 'entries/search', to: 'entries#search', as: 'search_entries'
      get 'entries/similar', to: 'entries#similar', as: 'similar_entries'

      get 'tags/popular', to: 'tags#popular', as: 'popular_tags'
      get 'tags/latest', to: 'tags#latest', as: 'latest_tags'
      get 'tags/search', to: 'tags#search', as: 'search_tags'

      get 'topics/popular', to: 'topics#popular', as: 'popular_topics'
      get 'topics/latest', to: 'topics#latest', as: 'latest_topics'
      get 'topics/search', to: 'topics#search', as: 'search_topics'

      get 'sites/popular', to: 'sites#popular', as: 'popular_sites_news'
      get 'sites/latest', to: 'sites#latest', as: 'latest_sites_news'
      get 'sites/search', to: 'sites#search', as: 'search_sites_news'
    end
  end
end
