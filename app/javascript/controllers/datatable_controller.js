import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["table"]
    static values = {
        pageLength: { type: Number, default: 25 },
        order: { type: Array, default: [[0, 'desc']] }
    }

    connect() {
        this.ensureDependencies()
    }

    disconnect() {
        this.destroyDataTable()
    }

    ensureDependencies() {
        // Load jQuery first
        if (typeof window.jQuery === 'undefined' && typeof window.$ === 'undefined') {
            this.loadScript('https://code.jquery.com/jquery-3.7.1.min.js')
                .then(() => {
                    window.$ = window.jQuery
                    return this.loadScript('https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js')
                })
                .then(() => {
                    this.initializeDataTable()
                })
                .catch(error => {
                    console.error('Failed to load dependencies:', error)
                })
        } else {
            // jQuery is available, check for DataTables
            if (typeof window.$.fn.DataTable === 'undefined') {
                this.loadScript('https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js')
                    .then(() => {
                        this.initializeDataTable()
                    })
                    .catch(error => {
                        console.error('Failed to load DataTables:', error)
                    })
            } else {
                this.initializeDataTable()
            }
        }
    }

    loadScript(src) {
        return new Promise((resolve, reject) => {
            // Check if script is already loaded
            const existingScript = document.querySelector(`script[src="${src}"]`)
            if (existingScript) {
                resolve()
                return
            }

            const script = document.createElement('script')
            script.src = src
            script.onload = resolve
            script.onerror = reject
            document.head.appendChild(script)
        })
    }

    initializeDataTable() {
        // Small delay to ensure everything is loaded
        setTimeout(() => {
            try {
                // Make sure we have jQuery and DataTables
                if (typeof window.$ === 'undefined' || typeof window.$.fn.DataTable === 'undefined') {
                    console.error('jQuery or DataTables not available')
                    return
                }

                // Destroy existing DataTable if it exists
                if (window.$.fn.DataTable.isDataTable(this.tableTarget)) {
                    window.$(this.tableTarget).DataTable().destroy()
                }

                // Initialize new DataTable
                const dataTable = window.$(this.tableTarget).DataTable({
                    order: this.orderValue,
                    language: this.getLanguageConfig(),
                    pageLength: this.pageLengthValue,
                    lengthChange: true,
                    lengthMenu: [[10, 25, 50, 100, -1], [10, 25, 50, 100, "Todos"]],
                    responsive: true,
                    dom: '<"flex flex-col sm:flex-row sm:items-center sm:justify-between mb-4"lf>rt<"flex flex-col sm:flex-row sm:items-center sm:justify-between mt-4"ip>',
                    columnDefs: [
                        {
                            targets: [1], // Image column
                            orderable: false,
                            searchable: false,
                            className: 'text-center'
                        },
                        {
                            targets: [2], // Title column
                            className: 'max-w-xs truncate'
                        },
                        {
                            targets: [3], // Tags column
                            className: 'text-xs'
                        },
                        {
                            targets: [5, 6, 7, 8], // Numeric columns
                            className: 'text-center font-semibold'
                        }
                    ],
                    processing: true,
                    loadingRecords: 'Cargando...',
                    processing: 'Procesando...',
                    initComplete: () => {
                        this.styleControls()
                        console.log('DataTable initialized successfully')
                    },
                    drawCallback: () => {
                        console.log('DataTable redrawn')
                    }
                })

                // Store reference for cleanup
                this.dataTableInstance = dataTable

            } catch (error) {
                console.error('Error initializing DataTable:', error)
            }
        }, 200)
    }

    destroyDataTable() {
        try {
            if (this.dataTableInstance && typeof window.$ !== 'undefined' && window.$.fn.DataTable) {
                if (window.$.fn.DataTable.isDataTable(this.tableTarget)) {
                    this.dataTableInstance.destroy()
                }
            }
        } catch (error) {
            console.error('Error destroying DataTable:', error)
        }
    }

    getLanguageConfig() {
        return {
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
            emptyTable: 'No hay datos disponibles en la tabla'
        }
    }

    styleControls() {
        try {
            // Custom styling after initialization
            window.$('.dataTables_wrapper .dataTables_length select, .dataTables_wrapper .dataTables_filter input')
                .addClass('form-select form-input')

            // Add search placeholder
            window.$('.dataTables_filter input').attr('placeholder', 'Buscar en todas las columnas...')

            // Style the controls container
            window.$('.dataTables_wrapper .dataTables_length').addClass('flex items-center space-x-2')
            window.$('.dataTables_wrapper .dataTables_filter').addClass('flex items-center space-x-2')
        } catch (error) {
            console.error('Error styling controls:', error)
        }
    }
}
