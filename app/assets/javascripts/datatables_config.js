// ============================================
// Morfeo Professional DataTables Configuration
// Unified, reusable DataTables initialization
// ============================================

window.MorfeoDataTables = {
  // Default configuration shared across all tables
  defaultConfig: {
    // Sorting
    order: [[0, 'desc']], // Sort by first column (usually date) descending
    
    // Pagination
    pageLength: 25,
    lengthChange: true,
    lengthMenu: [[10, 25, 50, 100, -1], [10, 25, 50, 100, "Todos"]],
    
    // Responsive
    responsive: true,
    
    // DOM layout with custom classes
    dom: '<"datatables-header"lf>rt<"datatables-footer"ip>',
    
    // Spanish language
    language: {
      search: 'Buscar:',
      lengthMenu: 'Mostrar _MENU_ entradas',
      info: 'Mostrando _START_ a _END_ de _TOTAL_ entradas',
      infoEmpty: 'Mostrando 0 a 0 de 0 entradas',
      infoFiltered: '(filtrado de _MAX_ entradas totales)',
      paginate: {
        first: 'Primero',
        last: 'Último',
        next: 'Siguiente',
        previous: 'Anterior'
      },
      emptyTable: 'No hay datos disponibles en la tabla',
      loadingRecords: 'Cargando...',
      processing: 'Procesando...',
      zeroRecords: 'No se encontraron registros coincidentes'
    },
    
    // Processing indicator
    processing: true,
    
    // Callbacks
    initComplete: function() {
      console.log('DataTable initialized successfully');
      // Add placeholder to search input
      $('.dataTables_filter input').attr('placeholder', 'Buscar en todas las columnas...');
    },
    
    drawCallback: function() {
      // Callback after each draw (pagination, search, etc.)
      console.log('DataTable redrawn');
    }
  },
  
  // Configuration for Entries table
  entriesConfig: {
    columnDefs: [
      {
        targets: [0], // Date column
        className: 'font-medium'
      },
      {
        targets: [1], // Title column
        className: 'max-w-xs'
      },
      {
        targets: [2], // Tags column
        className: 'text-xs',
        orderable: false
      },
      {
        targets: [4, 5, 6, 7], // Numeric columns (reactions, comments, shares, total)
        className: 'dt-center dt-number'
      }
    ],
    language: {
      info: 'Mostrando _START_ a _END_ de _TOTAL_ publicaciones',
      infoEmpty: 'Mostrando 0 a 0 de 0 publicaciones',
      infoFiltered: '(filtrado de _MAX_ publicaciones totales)'
    }
  },
  
  // Configuration for Facebook posts table
  facebookConfig: {
    columnDefs: [
      {
        targets: [0], // Date column
        className: 'font-medium'
      },
      {
        targets: [1], // Message column
        className: 'max-w-xs'
      },
      {
        targets: [2], // Type column
        className: 'dt-center',
        orderable: true
      },
      {
        targets: [3], // Tags column
        className: 'text-xs',
        orderable: false
      },
      {
        targets: [5], // Linked entry column
        className: 'dt-center',
        orderable: false
      },
      {
        targets: [6, 7, 8, 9, 10], // Numeric columns
        className: 'dt-center dt-number'
      }
    ],
    language: {
      info: 'Mostrando _START_ a _END_ de _TOTAL_ publicaciones',
      infoEmpty: 'Mostrando 0 a 0 de 0 publicaciones',
      infoFiltered: '(filtrado de _MAX_ publicaciones totales)'
    }
  },
  
  // Configuration for Twitter posts table
  twitterConfig: {
    columnDefs: [
      {
        targets: [0], // Date column
        className: 'font-medium'
      },
      {
        targets: [1], // Tweet text column
        className: 'max-w-xs'
      },
      {
        targets: [2], // Type column
        className: 'dt-center',
        orderable: true
      },
      {
        targets: [3], // Tags column
        className: 'text-xs',
        orderable: false
      },
      {
        targets: [5], // Linked entry column
        className: 'dt-center',
        orderable: false
      },
      {
        targets: [6, 7, 8, 9, 10], // Numeric columns
        className: 'dt-center dt-number'
      }
    ],
    language: {
      info: 'Mostrando _START_ a _END_ de _TOTAL_ tweets',
      infoEmpty: 'Mostrando 0 a 0 de 0 tweets',
      infoFiltered: '(filtrado de _MAX_ tweets totales)'
    }
  },
  
  // Initialize a DataTable with optional custom configuration
  init: function(selector, customConfig = {}, tableType = 'default') {
    // Get type-specific config
    let typeConfig = {};
    switch(tableType) {
      case 'entries':
        typeConfig = this.entriesConfig;
        break;
      case 'facebook':
        typeConfig = this.facebookConfig;
        break;
      case 'twitter':
        typeConfig = this.twitterConfig;
        break;
    }
    
    // Merge configurations: default < type-specific < custom
    const config = this.mergeDeep(
      {},
      this.defaultConfig,
      typeConfig,
      customConfig
    );
    
    // Find the table
    const $table = $(selector);
    
    // Destroy existing DataTable if it exists
    if ($.fn.DataTable.isDataTable($table)) {
      $table.DataTable().destroy();
    }
    
    // Initialize new DataTable
    return $table.DataTable(config);
  },
  
  // Initialize all tables on the page
  initAll: function() {
    // Entries tables
    $('.entries-datatable').each(function() {
      const tableId = '#' + $(this).attr('id');
      MorfeoDataTables.init(tableId, {}, 'entries');
    });
    
    // Facebook tables
    $('.facebook-posts-datatable').each(function() {
      const tableId = '#' + $(this).attr('id');
      MorfeoDataTables.init(tableId, {}, 'facebook');
    });
    
    // Twitter tables
    $('.twitter-posts-datatable').each(function() {
      const tableId = '#' + $(this).attr('id');
      MorfeoDataTables.init(tableId, {}, 'twitter');
    });
  },
  
  // Destroy all DataTables (useful for Turbo navigation)
  destroyAll: function() {
    $('.entries-datatable, .facebook-posts-datatable, .twitter-posts-datatable').each(function() {
      if ($.fn.DataTable.isDataTable(this)) {
        $(this).DataTable().destroy();
      }
    });
  },
  
  // Deep merge utility function
  mergeDeep: function(target, ...sources) {
    if (!sources.length) return target;
    const source = sources.shift();
    
    if (this.isObject(target) && this.isObject(source)) {
      for (const key in source) {
        if (this.isObject(source[key])) {
          if (!target[key]) Object.assign(target, { [key]: {} });
          this.mergeDeep(target[key], source[key]);
        } else {
          Object.assign(target, { [key]: source[key] });
        }
      }
    }
    
    return this.mergeDeep(target, ...sources);
  },
  
  // Check if value is an object
  isObject: function(item) {
    return item && typeof item === 'object' && !Array.isArray(item);
  }
};

// ============================================
// Auto-initialization
// ============================================

// Wait for libraries to load
function waitForDataTables(callback, maxAttempts = 50) {
  let attempts = 0;
  const checkInterval = setInterval(function() {
    attempts++;
    if (typeof window.$ !== 'undefined' && typeof window.$.fn.DataTable !== 'undefined') {
      clearInterval(checkInterval);
      console.log('jQuery and DataTables loaded successfully');
      callback();
    } else if (attempts >= maxAttempts) {
      clearInterval(checkInterval);
      console.error('jQuery or DataTables failed to load after ' + maxAttempts + ' attempts');
    }
  }, 100);
}

// Initialize on DOM ready
if (typeof $ !== 'undefined') {
  $(document).ready(function() {
    waitForDataTables(function() {
      MorfeoDataTables.initAll();
    });
  });
}

// Handle Turbo navigation (Rails 7)
document.addEventListener('turbo:load', function() {
  console.log('turbo:load event fired for DataTables');
  waitForDataTables(function() {
    MorfeoDataTables.initAll();
  });
});

// Clean up before Turbo caches the page
document.addEventListener('turbo:before-cache', function() {
  if (typeof $ !== 'undefined' && typeof $.fn.DataTable !== 'undefined') {
    MorfeoDataTables.destroyAll();
    console.log('All DataTables destroyed before cache');
  }
});

// ============================================
// Export for module systems (if needed)
// ============================================
if (typeof module !== 'undefined' && module.exports) {
  module.exports = MorfeoDataTables;
}

