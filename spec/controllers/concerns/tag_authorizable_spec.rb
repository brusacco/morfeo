# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TagAuthorizable do
  let(:host_class) do
    Class.new do
      include TagAuthorizable

      attr_accessor :tag, :topicos
    end
  end

  it 'checks access by merging topic relations without loading IDs' do
    allowed_topic = create(:topic)
    unrelated_topic = create(:topic)
    tag = create(:tag)
    allowed_topic.tags << tag
    topic_scope = Topic.where(id: allowed_topic.id)
    host = host_class.new
    host.tag = tag
    host.topicos = topic_scope

    expect(topic_scope).not_to receive(:pluck)
    expect(host.send(:user_has_tag_access?)).to be(true)
    expect(unrelated_topic.tags).not_to include(tag)
  end
end
