import { Controller } from "@hotwired/stimulus"

// Sentiment Chart Stimulus Controller
// Handles interactive features for sentiment trend charts
export default class extends Controller {
  static values = {
    id: String,
    url: String,
    topicId: Number
  }

  connect() {
    // Initialize chart-specific features
    this.setupTooltipFormatter()
  }

  // Setup custom tooltip formatter for Highcharts
  // This replaces the JavaScript string that was in the Ruby helper
  setupTooltipFormatter() {
    const chartElement = document.getElementById(this.idValue)
    
    if (chartElement && window.Highcharts) {
      const chart = window.Highcharts.charts.find(c => 
        c && c.renderTo && c.renderTo.id === this.idValue
      )
      
      if (chart) {
        chart.update({
          tooltip: {
            shared: true,
            crosshairs: true,
            formatter: this.tooltipFormatter.bind(this)
          }
        })
      }
    }
  }

  // Custom tooltip formatter function
  // Returns formatted HTML string for tooltip
  tooltipFormatter() {
    const points = this.points
    const dateStr = window.Highcharts.dateFormat('%e %b %Y', this.x)
    let html = `<b>${dateStr}</b>`
    let total = 0

    points.forEach(point => {
      const value = window.Highcharts.numberFormat(point.y, 0, ',', '.')
      html += `<br/><span style="color:${point.color}">●</span> `
      html += `${point.series.name}: <b>${value}</b>`
      total += point.y
    })

    const totalStr = window.Highcharts.numberFormat(total, 0, ',', '.')
    html += `<br/>Total: <b>${totalStr}</b>`

    return html
  }

  // Reload chart data via AJAX (for future use)
  async reloadData() {
    if (!this.hasUrlValue || !this.hasTopicIdValue) return

    try {
      const response = await fetch(
        `${this.urlValue}?topic_id=${this.topicIdValue}`,
        {
          headers: {
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          }
        }
      )

      if (response.ok) {
        const data = await response.json()
        this.updateChartData(data)
      }
    } catch (error) {
      console.error('Error reloading sentiment chart data:', error)
    }
  }

  // Update chart with new data
  updateChartData(data) {
    const chartElement = document.getElementById(this.idValue)
    
    if (chartElement && window.Highcharts) {
      const chart = window.Highcharts.charts.find(c => 
        c && c.renderTo && c.renderTo.id === this.idValue
      )
      
      if (chart && data.series) {
        data.series.forEach((seriesData, index) => {
          if (chart.series[index]) {
            chart.series[index].setData(seriesData.data, false)
          }
        })
        chart.redraw()
      }
    }
  }

  disconnect() {
    // Cleanup if needed
  }
}

