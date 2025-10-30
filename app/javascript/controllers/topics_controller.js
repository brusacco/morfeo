import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="topics"
export default class extends Controller {
  static targets = ['entries']
  static values = {
    id: String,
    url: String,
    topicId: String,
    title: String
  }

  connect() {
    // Wait for chart to be ready before setting up click events
    this.waitForChart();
  }

  waitForChart(attempts = 0, maxAttempts = 50) {
    const chart = Highcharts.charts.find(chart => chart && chart.renderTo && chart.renderTo.id === this.idValue);
    
    if (chart) {
      // Chart is ready, set up click events
      this.setupChartClickEvent();
      console.log(`Chart ${this.idValue} initialized with click handler`);
    } else if (attempts < maxAttempts) {
      // Chart not ready yet, try again in 100ms
      setTimeout(() => {
        this.waitForChart(attempts + 1, maxAttempts);
      }, 100);
    } else {
      console.warn(`Chart ${this.idValue} failed to initialize after ${maxAttempts} attempts`);
    }
  }

  setupChartClickEvent() {
    let chart = Highcharts.charts.find(chart => chart && chart.renderTo && chart.renderTo.id === this.idValue);
  
    if (chart) {
      let _this = this;
  
      chart.update({
        plotOptions: {
          series: {
            point: {
              events: {
                click: function (event) {
                  let polarity = event.point.series.name;

                  if (!['positive', 'negative', 'neutral'].includes(polarity)) {
                    polarity = '';
                  }

                  let formattedDate = _this.parseDateFromCategory(event.point.category);
                  
                  // topicId del controller
                  _this.loadEntries(_this.topicIdValue, formattedDate, polarity, _this.titleValue);
                }
              }
            }
          }
        }
      });
      
      console.log(`Click events attached to chart: ${this.idValue}`);
    }
  }

  parseDateFromCategory(category) {
    // Handle different date formats
    // Format 1: "30/10" (DD/MM from Facebook/Twitter)
    // Format 2: "2025-10-30" or Date object (from regular entries)
    
    if (typeof category === 'string' && category.match(/^\d{1,2}\/\d{1,2}$/)) {
      // Format: "DD/MM" - need to add current year
      const [day, month] = category.split('/');
      const year = new Date().getFullYear();
      const date = new Date(year, parseInt(month) - 1, parseInt(day));
      return date.toISOString().split('T')[0];
    } else {
      // Try to parse as regular date
      const clickedDate = new Date(category);
      if (!isNaN(clickedDate.getTime())) {
        return clickedDate.toISOString().split('T')[0];
      }
      // Fallback to today if parsing fails
      return new Date().toISOString().split('T')[0];
    }
  }
  
  loadEntries(topicId, date, polarity, title) {
    // Construir la URL
    fetch(this.urlValue + "?" + new URLSearchParams({
      topic_id: topicId,
      date: date,
      polarity: polarity,
      title: title
    }))
      .then(response => response.text())
      .then(html => {
        const modalEntries = document.getElementById(`${this.idValue}Entries`);
        if (modalEntries) {
          modalEntries.innerHTML = html;
          this.openModal();
        }
      });
  }

  openModal() {
    const modal = document.getElementById(`${this.idValue}Modal`);
    if (modal) {
      modal.classList.remove('hidden');
    }
  }
}
