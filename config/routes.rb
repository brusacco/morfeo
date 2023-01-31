# frozen_string_literal: true

Rails.application.routes.draw do
  get 'tag/show'
  get 'entry/show'
  get 'entry/popular', as: 'popular_entries'
  get 'entry/commented', as: 'commented_entries'
  get '/site/:id', to: 'site#show', as: 'site'
  get '/tag/:id', to: 'tag#show', as: 'tag'
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  get 'home/index'
  get 'home/check'
  root 'home#index'
end
