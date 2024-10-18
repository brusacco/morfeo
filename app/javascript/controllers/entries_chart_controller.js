import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="entries-chart"
export default class extends Controller {
  static targets = ['entries']
  static values = {
    id: String,
    url: String,
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

                  _this.loadEntries(topicId, formattedDate);
                }
              }
            }
          }
        }
      });
    }
  }

  loadEntries(topicId, date) {
    fetch(this.urlValue + "?" + new URLSearchParams({ topic_id: topicId, date: date }))
      .then(response => response.text())
      .then(html => {
        this.entriesTarget.innerHTML = html;
        this.openModal();
      });
  }

  openModal() {
    document.getElementById('entriesModal').classList.remove('hidden');
  }

  closeModal() {
    document.getElementById('entriesModal').classList.add('hidden');
  }
}
