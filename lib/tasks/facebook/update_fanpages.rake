# frozen_string_literal: true

namespace :facebook do
  desc 'Update Fanpage Stats'
  task update_fanpages: :environment do
    pages = Page.where.not(uid: nil)
    pages.each do |page|
      puts "Process Fanpage: #{page.name}"
      response = FacebookServices::UpdatePage.call(page.uid)
      page.update!(response.data) if response.success?
    end
  end
end
