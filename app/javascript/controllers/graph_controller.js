import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    id: String
  }

  connect() {
    console.log('Connected')
    console.log(this.idValue)

    // Get the Highcharts chart instance
    var chart = Highcharts.charts.find(c => c.renderTo.id === this.idValue);
    
    if (chart) {
      // Set the click event handler
      Highcharts.addEvent(chart, 'click', function(event) {
        if (event.point) {
          let xAxisIndex = event.point.index;
          let label = chart.xAxis[0].categories[xAxisIndex] || 'Unknown';
          console.log(`Clicked on data point with label "${label}"`);
        }
      });
    } else {
      console.warn(`No chart found with id "${this.idValue}"`);
    }
  }
}
