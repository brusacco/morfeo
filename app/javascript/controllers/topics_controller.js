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
    this.setupChartClickEvent();
  }

  setupChartClickEvent() {
    let chart = Highcharts.charts.find(chart => chart.renderTo.id === this.idValue);
  
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

                  let clickedDate = new Date(event.point.category);
                  const formattedDate = clickedDate.toISOString().split('T')[0];
                  
                  // topicId del controller
                  _this.loadEntries(_this.topicIdValue, formattedDate, polarity, _this.titleValue);
                }
              }
            }
          }
        }
      });
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
