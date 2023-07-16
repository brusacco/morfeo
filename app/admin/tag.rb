# frozen_string_literal: true

ActiveAdmin.register Tag do
  permit_params :name, :variations, topic_ids: []

  #------------------------------------------------------------------
  #
  #------------------------------------------------------------------
  action_item :retag_entries, only: %i[edit show] do
    link_to 'Retag entries', retag_entries_admin_tag_path(tag.id), method: :put, data: { confirm: 'Are you sure?' }
  end

  #------------------------------------------------------------------
  #
  #------------------------------------------------------------------
  member_action :retag_entries, method: :put do
    Tags::UpdateTagEntriesJob.perform_later(params[:id])
    redirect_to admin_tags_path, notice: 'Running tag updates'
  end

  filter :name
  filter :variations

  #------------------------------------------------------------------
  #
  #------------------------------------------------------------------
  index do
    selectable_column
    id_column
    column 'Name' do |tag|
      link_to tag.name, tag_path(tag), target: :blank
    end
    column :variations
    column :created_at
    column :taggings_count
    column :topics
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :variations
      f.input :topics
    end
    f.actions
  end
end
