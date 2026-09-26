# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metric provenance copy' do
  def template(path)
    File.read(Rails.root.join(path))
  end

  it 'identifies Facebook views as Morfeo estimates in dashboard and PDF output' do
    expect(template('app/views/facebook_topic/show.html.erb')).to include(
      'Visualizaciones estimadas',
      'Estimación de Morfeo basada en seguidores e interacciones.'
    )
    expect(template('app/views/facebook_topic/pdf.html.erb')).to include(
      'Visualizaciones estimadas',
      'estimación de Morfeo; no es alcance único'
    )
    expect(template('app/views/facebook_topic/_facebook_entry.html.erb')).to include(
      'Visualizaciones estimadas',
      'no es una métrica proporcionada directamente por Facebook.'
    )
  end

  it 'does not present mixed General totals as unique people reached' do
    expect(template('app/views/general_dashboard/show.html.erb')).to include(
      'Visualizaciones y alcance potencial estimados',
      'no representa personas únicas.'
    )
    expect(template('app/views/general_dashboard/pdf.html.erb')).to include(
      'visualizaciones y alcance potencial estimados',
      'no representa personas únicas.'
    )
  end

  it 'retains observed terminology for X views and Instagram video views' do
    expect(template('app/views/twitter_topic/pdf.html.erb')).to include('alcance oficial Twitter API')
    expect(template('app/views/instagram_topic/pdf.html.erb')).to include('vistas de video observadas del proveedor')
  end
end