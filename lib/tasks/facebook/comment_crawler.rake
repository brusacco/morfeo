# frozen_string_literal: true

require 'digest'

namespace :facebook do
  desc 'Facebook comments crawler'
  task comment_crawler: :environment do
    entries = Entry.where.not(uid: nil).where.not(comment_count: 0)
    # entries = Entry.where(id: 207_794)
    entries.find_each do |entry|
      puts entry.id
      puts entry.url
      puts "Comment count: #{entry.comment_count}"
      puts entry.uid
      puts '--------------------------------'
      response = FacebookServices::CommentCrawler.call(entry.uid)
      data = response[:data]

      data[:comments].each do |comment|
        comment_uid = generate_hash(comment['created_time'], comment['message'])
        puts comment_uid
        Comment.find_or_create_by!(uid: comment_uid) do |db_comment|
          db_comment.entry_id = entry.id
          db_comment.message = comment['message']
          db_comment.created_time = comment['created_time']
        end
      end
    end
  end

  def generate_hash(created_time, message)
    concatenated_data = "#{created_time}#{message}"
    Digest::SHA256.hexdigest(concatenated_data)
  end
end
