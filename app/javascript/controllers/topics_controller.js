import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="topics"
export default class extends Controller {
  static targets = ['entries']
  static values = {
    id: String,
    url: String,
    topicId: String
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
                  let polarity = event.point.series.options.polarity;
                  console.log("polarity: " + polarity);
                  
                  let clickedDate = new Date(event.point.category);
                  const formattedDate = clickedDate.toISOString().split('T')[0];
                  
                  // topicId del controller
                  _this.loadEntries(_this.topicIdValue, formattedDate);
                }
              }
            }
          }
        }
      });
    }
  }
  
  loadEntries(topicId, date) {
    // Construir URL con topicId y fecha seleccionada
    fetch(this.urlValue + "?" + new URLSearchParams({ topic_id: topicId, date: date }))
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

  // closeModal() {
  //   const modal = this.element.closest('.outside').querySelector('.fixed');
  //   if (modal) {
  //     modal.classList.add('hidden');
  //   }
  // }
  
}
