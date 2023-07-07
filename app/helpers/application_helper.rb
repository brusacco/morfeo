# frozen_string_literal: true

module ApplicationHelper
  def active_link_to(name = nil, options = nil, html_options = {}, &block)
    active_class = html_options[:active] || 'active aria-current="page"'
    html_options.delete(:active)
    html_options[:class] = "#{html_options[:class]} #{active_class}" if current_page?(options)
    link_to(name, options, html_options, &block)
  end

  def clean_title(title)
    title.split(' | ').first
  end
end
