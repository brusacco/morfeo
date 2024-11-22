import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="entries-chart"
export default class extends Controller {
  static targets = ['entries']
  static values = {
    id: String,
    url: String,
    polarity: String
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
                  let topicId = event.point.series.options.topicId;
                  let clickedDate = new Date(event.point.category);
                  const formattedDate = clickedDate.toISOString().split('T')[0];
                  let polarity = _this.polarityValue

                  _this.loadEntries(topicId, formattedDate, polarity);
                }
              }
            }
          }
        }
      });
    }
  }

  loadEntries(topicId, date, polarity) {
    fetch(this.urlValue + "?" + new URLSearchParams({ topic_id: topicId, date: date, polarity: polarity }))
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
