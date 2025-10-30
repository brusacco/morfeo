// ============================================
// Morfeo Professional Highcharts Configuration
// Unified, reusable chart styling and defaults
// ============================================

window.MorfeoCharts = {
  // Professional color palette for data visualization
  colors: [
    '#3B82F6', // blue-500
    '#10B981', // green-500
    '#F59E0B', // amber-500
    '#EF4444', // red-500
    '#8B5CF6', // purple-500
    '#EC4899', // pink-500
    '#6366F1', // indigo-500
    '#14B8A6', // teal-500
    '#F97316', // orange-500
    '#06B6D4'  // cyan-500
  ],

  // Default configuration for all charts
  defaultOptions: {
    chart: {
      style: {
        fontFamily: 'Inter, system-ui, -apple-system, sans-serif'
      },
      backgroundColor: 'transparent',
      spacing: [20, 20, 20, 20]
    },
    
    title: {
      style: {
        fontSize: '18px',
        fontWeight: '600',
        color: '#111827', // gray-900
        letterSpacing: '-0.01em'
      },
      align: 'left'
    },
    
    subtitle: {
      style: {
        fontSize: '14px',
        fontWeight: '400',
        color: '#6B7280' // gray-500
      },
      align: 'left'
    },
    
    credits: {
      enabled: false
    },
    
    legend: {
      align: 'center',
      verticalAlign: 'bottom',
      layout: 'horizontal',
      itemStyle: {
        fontSize: '14px',
        fontWeight: '500',
        color: '#6B7280' // gray-500
      },
      itemHoverStyle: {
        color: '#111827' // gray-900
      },
      itemMarginBottom: 8,
      symbolRadius: 6,
      symbolHeight: 12,
      symbolWidth: 12
    },
    
    tooltip: {
      backgroundColor: '#1F2937', // gray-800
      borderColor: '#374151', // gray-700
      borderRadius: 8,
      borderWidth: 1,
      shadow: {
        color: 'rgba(0, 0, 0, 0.2)',
        offsetX: 0,
        offsetY: 2,
        opacity: 0.5,
        width: 4
      },
      style: {
        color: '#F9FAFB', // gray-50
        fontSize: '13px',
        fontWeight: '400'
      },
      padding: 12,
      useHTML: true
    },
    
    xAxis: {
      labels: {
        style: {
          fontSize: '12px',
          color: '#6B7280', // gray-500
          fontWeight: '400'
        }
      },
      gridLineColor: '#E5E7EB', // gray-200
      lineColor: '#D1D5DB', // gray-300
      tickColor: '#D1D5DB' // gray-300
    },
    
    yAxis: {
      labels: {
        style: {
          fontSize: '12px',
          color: '#6B7280', // gray-500
          fontWeight: '400'
        }
      },
      gridLineColor: '#E5E7EB', // gray-200
      lineColor: '#D1D5DB', // gray-300
      title: {
        style: {
          fontSize: '13px',
          fontWeight: '500',
          color: '#6B7280' // gray-500
        }
      }
    },
    
    plotOptions: {
      series: {
        animation: {
          duration: 800,
          easing: 'easeOutQuart'
        },
        marker: {
          radius: 4,
          lineWidth: 2,
          lineColor: '#FFFFFF'
        },
        states: {
          hover: {
            lineWidthPlus: 1
          }
        }
      },
      column: {
        borderRadius: 4,
        borderWidth: 0
      },
      bar: {
        borderRadius: 4,
        borderWidth: 0
      },
      pie: {
        borderWidth: 0,
        dataLabels: {
          style: {
            fontSize: '13px',
            fontWeight: '500',
            color: '#374151', // gray-700
            textOutline: 'none'
          }
        }
      },
      area: {
        fillOpacity: 0.1,
        lineWidth: 2,
        marker: {
          radius: 3
        }
      }
    }
  },

  // Specific configuration for line charts
  lineChartOptions: {
    chart: {
      type: 'line'
    },
    plotOptions: {
      line: {
        lineWidth: 3,
        marker: {
          enabled: true,
          radius: 4
        }
      }
    }
  },

  // Specific configuration for area charts
  areaChartOptions: {
    chart: {
      type: 'area'
    },
    plotOptions: {
      area: {
        fillOpacity: 0.15,
        lineWidth: 2,
        marker: {
          enabled: true,
          radius: 3
        }
      }
    }
  },

  // Specific configuration for column charts
  columnChartOptions: {
    chart: {
      type: 'column'
    },
    plotOptions: {
      column: {
        borderRadius: 6,
        pointPadding: 0.1,
        groupPadding: 0.15
      }
    }
  },

  // Specific configuration for bar charts
  barChartOptions: {
    chart: {
      type: 'bar'
    },
    plotOptions: {
      bar: {
        borderRadius: 6,
        pointPadding: 0.1,
        groupPadding: 0.15
      }
    }
  },

  // Specific configuration for pie charts
  pieChartOptions: {
    chart: {
      type: 'pie'
    },
    plotOptions: {
      pie: {
        allowPointSelect: true,
        cursor: 'pointer',
        dataLabels: {
          enabled: true,
          format: '<b>{point.name}</b>: {point.percentage:.1f}%'
        },
        showInLegend: true
      }
    }
  },

  // Specific configuration for spline charts
  splineChartOptions: {
    chart: {
      type: 'spline'
    },
    plotOptions: {
      spline: {
        lineWidth: 3,
        marker: {
          enabled: true,
          radius: 4
        }
      }
    }
  },

  // Helper: Merge configurations
  mergeOptions: function(...configs) {
    return configs.reduce((merged, config) => {
      return this.deepMerge(merged, config);
    }, {});
  },

  // Helper: Deep merge utility
  deepMerge: function(target, source) {
    const output = Object.assign({}, target);
    if (this.isObject(target) && this.isObject(source)) {
      Object.keys(source).forEach(key => {
        if (this.isObject(source[key])) {
          if (!(key in target)) {
            Object.assign(output, { [key]: source[key] });
          } else {
            output[key] = this.deepMerge(target[key], source[key]);
          }
        } else {
          Object.assign(output, { [key]: source[key] });
        }
      });
    }
    return output;
  },

  // Helper: Check if value is object
  isObject: function(item) {
    return item && typeof item === 'object' && !Array.isArray(item);
  },

  // Create a chart with merged options
  createChart: function(containerId, chartType, customOptions = {}) {
    let typeOptions = {};
    
    // Get type-specific options
    switch(chartType) {
      case 'line':
        typeOptions = this.lineChartOptions;
        break;
      case 'area':
        typeOptions = this.areaChartOptions;
        break;
      case 'column':
        typeOptions = this.columnChartOptions;
        break;
      case 'bar':
        typeOptions = this.barChartOptions;
        break;
      case 'pie':
        typeOptions = this.pieChartOptions;
        break;
      case 'spline':
        typeOptions = this.splineChartOptions;
        break;
    }
    
    // Merge: default < type-specific < custom
    const finalOptions = this.mergeOptions(
      this.defaultOptions,
      typeOptions,
      { colors: this.colors },
      customOptions
    );
    
    // Create the chart
    return Highcharts.chart(containerId, finalOptions);
  },

  // Apply default options globally to Highcharts
  applyDefaults: function() {
    if (typeof Highcharts !== 'undefined') {
      Highcharts.setOptions({
        colors: this.colors,
        ...this.defaultOptions
      });
      console.log('Morfeo Charts: Default options applied to Highcharts');
    } else {
      console.warn('Morfeo Charts: Highcharts not loaded yet');
    }
  },

  // Format tooltip with professional styling
  formatTooltip: function(point, seriesName = null) {
    const name = seriesName || point.series.name;
    const value = typeof point.y === 'number' ? point.y.toLocaleString() : point.y;
    const color = point.color || point.series.color;
    
    return `
      <div style="padding: 4px 0;">
        <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
          <span style="display: inline-block; width: 12px; height: 12px; border-radius: 3px; background-color: ${color};"></span>
          <span style="font-weight: 600; color: #F9FAFB;">${name}</span>
        </div>
        <div style="font-size: 18px; font-weight: 700; color: #FFFFFF; margin-left: 20px;">
          ${value}
        </div>
        ${point.name ? `<div style="font-size: 12px; color: #D1D5DB; margin-left: 20px; margin-top: 2px;">${point.name}</div>` : ''}
      </div>
    `;
  },

  // Format number with K, M, B suffixes
  formatNumber: function(num) {
    if (num >= 1000000000) {
      return (num / 1000000000).toFixed(1) + 'B';
    }
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    }
    if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
  }
};

// ============================================
// Auto-initialization
// ============================================

// Wait for Highcharts to load
function waitForHighcharts(callback, maxAttempts = 50) {
  let attempts = 0;
  const checkInterval = setInterval(function() {
    attempts++;
    if (typeof Highcharts !== 'undefined') {
      clearInterval(checkInterval);
      console.log('Highcharts loaded successfully');
      callback();
    } else if (attempts >= maxAttempts) {
      clearInterval(checkInterval);
      console.error('Highcharts failed to load after ' + maxAttempts + ' attempts');
    }
  }, 100);
}

// Apply defaults when Highcharts is ready
if (typeof Highcharts !== 'undefined') {
  MorfeoCharts.applyDefaults();
} else {
  // Wait for Highcharts to load
  waitForHighcharts(function() {
    MorfeoCharts.applyDefaults();
  });
}

// Reapply on Turbo navigation
document.addEventListener('turbo:load', function() {
  console.log('turbo:load event fired for Highcharts');
  waitForHighcharts(function() {
    MorfeoCharts.applyDefaults();
  });
});

// ============================================
// Export for module systems (if needed)
// ============================================
if (typeof module !== 'undefined' && module.exports) {
  module.exports = MorfeoCharts;
}

