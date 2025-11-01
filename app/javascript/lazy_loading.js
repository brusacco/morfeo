// Lazy Loading & Performance JavaScript for Morfeo
// Handles intersection observer, image lazy loading, and performance monitoring

(function() {
  'use strict';

  // ==================================
  // LAZY LOAD IMAGES
  // ==================================
  
  function initLazyImages() {
    // Use native lazy loading if supported
    if ('loading' in HTMLImageElement.prototype) {
      const images = document.querySelectorAll('img[data-src]');
      images.forEach(img => {
        img.src = img.dataset.src;
        img.loading = 'lazy';
        if (img.dataset.srcset) {
          img.srcset = img.dataset.srcset;
        }
        img.classList.add('loaded');
      });
    } else {
      // Fallback to Intersection Observer
      const imageObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const img = entry.target;
            img.src = img.dataset.src;
            if (img.dataset.srcset) {
              img.srcset = img.dataset.srcset;
            }
            img.classList.add('loaded');
            observer.unobserve(img);
          }
        });
      }, {
        rootMargin: '50px 0px',
        threshold: 0.01
      });

      const images = document.querySelectorAll('img[data-src]');
      images.forEach(img => imageObserver.observe(img));
    }
  }

  // ==================================
  // LAZY LOAD SECTIONS
  // ==================================
  
  function initLazySections() {
    const sectionObserver = new IntersectionObserver((entries, observer) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('loaded');
          observer.unobserve(entry.target);
        }
      });
    }, {
      rootMargin: '100px 0px',
      threshold: 0.1
    });

    const sections = document.querySelectorAll('.lazy-load');
    sections.forEach(section => sectionObserver.observe(section));
  }

  // ==================================
  // LAZY LOAD CHARTS
  // ==================================
  
  function initLazyCharts() {
    const chartObserver = new IntersectionObserver((entries, observer) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const chartContainer = entry.target;
          const chartData = chartContainer.dataset.chart;
          
          if (chartData) {
            try {
              // Trigger chart rendering
              const event = new CustomEvent('lazyLoadChart', {
                detail: { container: chartContainer, data: JSON.parse(chartData) }
              });
              document.dispatchEvent(event);
              
              chartContainer.classList.add('loaded');
              observer.unobserve(chartContainer);
            } catch (e) {
              console.error('Error loading chart:', e);
            }
          }
        }
      });
    }, {
      rootMargin: '200px 0px',
      threshold: 0.01
    });

    const charts = document.querySelectorAll('.chart-lazy-load');
    charts.forEach(chart => chartObserver.observe(chart));
  }

  // ==================================
  // PREFETCH ON HOVER
  // ==================================
  
  function initPrefetchOnHover() {
    const prefetchLinks = document.querySelectorAll('a[data-prefetch]');
    const prefetched = new Set();

    prefetchLinks.forEach(link => {
      link.addEventListener('mouseenter', function() {
        const href = this.getAttribute('href');
        
        if (href && !prefetched.has(href)) {
          const linkElement = document.createElement('link');
          linkElement.rel = 'prefetch';
          linkElement.href = href;
          document.head.appendChild(linkElement);
          prefetched.add(href);
        }
      }, { passive: true });
    });
  }

  // ==================================
  // PERFORMANCE MONITORING
  // ==================================
  
  function initPerformanceMonitoring() {
    // Web Vitals monitoring
    if ('PerformanceObserver' in window) {
      // Largest Contentful Paint (LCP)
      const lcpObserver = new PerformanceObserver((list) => {
        const entries = list.getEntries();
        const lastEntry = entries[entries.length - 1];
        console.log('LCP:', lastEntry.renderTime || lastEntry.loadTime);
      });
      
      try {
        lcpObserver.observe({ entryTypes: ['largest-contentful-paint'] });
      } catch (e) {
        // Browser doesn't support LCP
      }

      // First Input Delay (FID)
      const fidObserver = new PerformanceObserver((list) => {
        list.getEntries().forEach(entry => {
          console.log('FID:', entry.processingStart - entry.startTime);
        });
      });
      
      try {
        fidObserver.observe({ entryTypes: ['first-input'] });
      } catch (e) {
        // Browser doesn't support FID
      }

      // Cumulative Layout Shift (CLS)
      let clsScore = 0;
      const clsObserver = new PerformanceObserver((list) => {
        list.getEntries().forEach(entry => {
          if (!entry.hadRecentInput) {
            clsScore += entry.value;
            console.log('CLS:', clsScore);
          }
        });
      });
      
      try {
        clsObserver.observe({ entryTypes: ['layout-shift'] });
      } catch (e) {
        // Browser doesn't support CLS
      }
    }

    // Navigation Timing
    if (window.performance && window.performance.timing) {
      window.addEventListener('load', function() {
        setTimeout(function() {
          const perfData = window.performance.timing;
          const pageLoadTime = perfData.loadEventEnd - perfData.navigationStart;
          const connectTime = perfData.responseEnd - perfData.requestStart;
          const renderTime = perfData.domComplete - perfData.domLoading;
          
          console.log('Page Load Time:', pageLoadTime, 'ms');
          console.log('Connect Time:', connectTime, 'ms');
          console.log('Render Time:', renderTime, 'ms');
        }, 0);
      });
    }
  }

  // ==================================
  // PROGRESSIVE IMAGE LOADING
  // ==================================
  
  function initProgressiveImages() {
    const progressiveImages = document.querySelectorAll('.progressive-image');
    
    progressiveImages.forEach(container => {
      const fullImg = container.querySelector('.full');
      
      if (fullImg) {
        const img = new Image();
        img.src = fullImg.dataset.src || fullImg.src;
        
        img.onload = function() {
          fullImg.src = img.src;
          container.classList.add('loaded');
        };
      }
    });
  }

  // ==================================
  // VIRTUAL SCROLLING (SIMPLE VERSION)
  // ==================================
  
  function initVirtualScrolling(containerId, itemHeight, totalItems) {
    const container = document.getElementById(containerId);
    if (!container) return;

    const content = container.querySelector('.virtual-scroll-content');
    const spacer = container.querySelector('.virtual-scroll-spacer');
    
    if (!content || !spacer) return;

    const viewportHeight = container.clientHeight;
    const bufferSize = 5;
    
    spacer.style.height = (totalItems * itemHeight) + 'px';

    function updateVisibleItems() {
      const scrollTop = container.scrollTop;
      const startIndex = Math.max(0, Math.floor(scrollTop / itemHeight) - bufferSize);
      const endIndex = Math.min(totalItems, Math.ceil((scrollTop + viewportHeight) / itemHeight) + bufferSize);
      
      // Trigger custom event to update items
      const event = new CustomEvent('updateVirtualScroll', {
        detail: { startIndex, endIndex, offset: startIndex * itemHeight }
      });
      container.dispatchEvent(event);
    }

    container.addEventListener('scroll', updateVisibleItems, { passive: true });
    updateVisibleItems(); // Initial render
  }

  // ==================================
  // SMOOTH SCROLL POLYFILL
  // ==================================
  
  function initSmoothScroll() {
    // Check if smooth scroll is not supported
    if (!('scrollBehavior' in document.documentElement.style)) {
      const links = document.querySelectorAll('a[href^="#"]');
      
      links.forEach(link => {
        link.addEventListener('click', function(e) {
          const href = this.getAttribute('href');
          if (href === '#') return;
          
          const target = document.querySelector(href);
          if (target) {
            e.preventDefault();
            target.scrollIntoView({ behavior: 'smooth' });
          }
        });
      });
    }
  }

  // ==================================
  // DEBOUNCE HELPER
  // ==================================
  
  function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }

  // ==================================
  // THROTTLE HELPER
  // ==================================
  
  function throttle(func, limit) {
    let inThrottle;
    return function(...args) {
      if (!inThrottle) {
        func.apply(this, args);
        inThrottle = true;
        setTimeout(() => inThrottle = false, limit);
      }
    };
  }

  // ==================================
  // REQUEST IDLE CALLBACK POLYFILL
  // ==================================
  
  window.requestIdleCallback = window.requestIdleCallback || function(cb) {
    const start = Date.now();
    return setTimeout(function() {
      cb({
        didTimeout: false,
        timeRemaining: function() {
          return Math.max(0, 50 - (Date.now() - start));
        }
      });
    }, 1);
  };

  window.cancelIdleCallback = window.cancelIdleCallback || function(id) {
    clearTimeout(id);
  };

  // ==================================
  // INITIALIZE ALL
  // ==================================
  
  function init() {
    // Only run in browser
    if (typeof window === 'undefined') return;

    // Initialize lazy loading
    initLazyImages();
    initLazySections();
    initLazyCharts();
    
    // Initialize prefetching
    initPrefetchOnHover();
    
    // Initialize progressive images
    initProgressiveImages();
    
    // Initialize smooth scroll
    initSmoothScroll();
    
    // Initialize performance monitoring (only in development)
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
      initPerformanceMonitoring();
    }
  }

  // Run on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Reinitialize on Turbo navigation
  if (typeof Turbo !== 'undefined') {
    document.addEventListener('turbo:load', init);
    document.addEventListener('turbo:render', init);
  }

  // Export for use in other scripts
  window.MorfeoPerformance = {
    initLazyImages,
    initLazySections,
    initLazyCharts,
    initVirtualScrolling,
    debounce,
    throttle
  };

})();

