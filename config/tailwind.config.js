const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      // Font Family
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
      
      // Typography Scale - Professional Design System
      fontSize: {
        // Display sizes (hero sections, landing pages)
        'display-lg': ['3.75rem', { lineHeight: '1.1', fontWeight: '700', letterSpacing: '-0.025em' }],
        'display-md': ['3rem', { lineHeight: '1.2', fontWeight: '700', letterSpacing: '-0.025em' }],
        
        // Heading sizes (page/section titles)
        'heading-xl': ['2.25rem', { lineHeight: '1.3', fontWeight: '600', letterSpacing: '-0.015em' }],
        'heading-lg': ['1.875rem', { lineHeight: '1.3', fontWeight: '600', letterSpacing: '-0.01em' }],
        'heading-md': ['1.5rem', { lineHeight: '1.4', fontWeight: '600' }],
        'heading-sm': ['1.25rem', { lineHeight: '1.4', fontWeight: '600' }],
        'heading-xs': ['1.125rem', { lineHeight: '1.4', fontWeight: '600' }],
        
        // Body text sizes
        'body-lg': ['1.125rem', { lineHeight: '1.75', fontWeight: '400' }],
        'body-md': ['1rem', { lineHeight: '1.5', fontWeight: '400' }],
        'body-sm': ['0.875rem', { lineHeight: '1.5', fontWeight: '400' }],
        
        // UI element sizes
        'label': ['0.875rem', { lineHeight: '1.25', fontWeight: '500' }],
        'caption': ['0.75rem', { lineHeight: '1.25', fontWeight: '400' }],
        'overline': ['0.75rem', { lineHeight: '1.25', fontWeight: '600', letterSpacing: '0.05em', textTransform: 'uppercase' }],
      },
      
      // Color Palette Extensions (if needed beyond Tailwind defaults)
      colors: {
        // Primary brand colors (Indigo is default, but explicit for clarity)
        primary: {
          50: '#eef2ff',
          100: '#e0e7ff',
          200: '#c7d2fe',
          300: '#a5b4fc',
          400: '#818cf8',
          500: '#6366f1',
          600: '#4f46e5', // Main brand color
          700: '#4338ca',
          800: '#3730a3',
          900: '#312e81',
        },
        
        // Social media brand colors
        facebook: '#1877f2',
        twitter: '#1da1f2',
        instagram: '#e4405f',
        linkedin: '#0a66c2',
        youtube: '#ff0000',
      },
      
      // Chart/Data Visualization Colors
      chartColors: {
        1: '#3b82f6',  // Blue
        2: '#10b981',  // Green
        3: '#f59e0b',  // Amber
        4: '#ef4444',  // Red
        5: '#8b5cf6',  // Purple
        6: '#ec4899',  // Pink
        7: '#6366f1',  // Indigo
        8: '#14b8a6',  // Teal
      },
      
      // Spacing (extended for design system needs)
      spacing: {
        '18': '4.5rem',   // 72px
        '88': '22rem',    // 352px
        '128': '32rem',   // 512px
        '144': '36rem',   // 576px
      },
      
      // Border Radius (emphasize rounded-xl as default)
      borderRadius: {
        'xl': '0.75rem',  // 12px - preferred for cards
        '2xl': '1rem',     // 16px
        '3xl': '1.5rem',   // 24px
      },
      
      // Box Shadow (enhanced elevation scale)
      boxShadow: {
        'sm': '0 1px 2px 0 rgb(0 0 0 / 0.05)',
        DEFAULT: '0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1)',
        'md': '0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)',
        'lg': '0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)',
        'xl': '0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)',
        '2xl': '0 25px 50px -12px rgb(0 0 0 / 0.25)',
        'inner': 'inset 0 2px 4px 0 rgb(0 0 0 / 0.05)',
      },
      
      // Animation & Transitions
      transitionDuration: {
        '400': '400ms',
        '600': '600ms',
      },
      
      // Z-index scale
      zIndex: {
        '60': '60',
        '70': '70',
        '80': '80',
        '90': '90',
        '100': '100',
      },
    },
  },
  plugins: [
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ]
}
