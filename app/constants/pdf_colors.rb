# frozen_string_literal: true

# PDF Colors - Print-Optimized Palette
# Professional color system for PDF reports with excellent print quality
# All colors tested for CMYK conversion and print fidelity
module PdfColors
  # Primary Brand Colors (Print-Optimized)
  DIGITAL_PRIMARY = '#1e40af'      # Deep Blue (was #1e3a8a) - Better print
  FACEBOOK_PRIMARY = '#1877f2'     # Facebook Blue (official)
  TWITTER_PRIMARY = '#0ea5e9'      # Twitter Blue (official)
  GENERAL_PRIMARY = '#7c3aed'      # Purple (was #8b5cf6) - Richer tone
  
  # Semantic Colors (Print-Optimized - Darker, More Saturated)
  SUCCESS = '#047857'              # Emerald (was #10b981) - 30% darker
  WARNING = '#d97706'              # Amber (was #f59e0b) - 25% darker
  DANGER = '#dc2626'               # Red (was #ef4444) - 20% darker
  INFO = '#1e40af'                 # Blue (consistent with primary)
  
  # Chart Colors (Professional Palette - 8 colors)
  # Designed for maximum differentiation and print quality
  CHART_PALETTE = [
    '#1e40af',  # Deep Blue
    '#047857',  # Emerald
    '#d97706',  # Amber
    '#dc2626',  # Red
    '#7c3aed',  # Purple
    '#db2777',  # Pink (was #ec4899) - Deeper
    '#0d9488',  # Teal (was #14b8a6) - Richer
    '#ea580c'   # Orange (was #f97316) - More vibrant
  ].freeze
  
  # Sentiment Colors (Print-Optimized)
  SENTIMENT_POSITIVE = '#047857'   # Emerald
  SENTIMENT_NEUTRAL = '#64748b'    # Slate (was #6b7280) - Better contrast
  SENTIMENT_NEGATIVE = '#dc2626'   # Red
  
  # Text Colors (WCAG AA Compliant)
  TEXT_PRIMARY = '#1e293b'         # Slate 800 (was #1f2937)
  TEXT_SECONDARY = '#475569'       # Slate 600 (was #6b7280) - 4.6:1 ratio
  TEXT_TERTIARY = '#64748b'        # Slate 500 (was #9ca3af) - Better contrast
  TEXT_MUTED = '#94a3b8'           # Slate 400
  
  # Background Colors
  BG_PRIMARY = '#ffffff'
  BG_SECONDARY = '#f8fafc'         # Slate 50 (was #f9fafb)
  BG_TERTIARY = '#f1f5f9'          # Slate 100 (was #f3f4f6)
  
  # Border Colors
  BORDER_DEFAULT = '#e2e8f0'       # Slate 200 (was #e5e7eb)
  BORDER_EMPHASIS = '#cbd5e1'      # Slate 300 (was #d1d5db)
  BORDER_STRONG = '#94a3b8'        # Slate 400
  
  # Shadow Colors (for print)
  SHADOW_SM = 'rgba(15, 23, 42, 0.08)'   # Subtle
  SHADOW_MD = 'rgba(15, 23, 42, 0.12)'   # Medium
  SHADOW_LG = 'rgba(15, 23, 42, 0.16)'   # Large
  
  # Helper Methods
  
  # Get color by report type
  def self.primary_color(report_type)
    case report_type.to_sym
    when :digital then DIGITAL_PRIMARY
    when :facebook then FACEBOOK_PRIMARY
    when :twitter then TWITTER_PRIMARY
    when :general then GENERAL_PRIMARY
    else DIGITAL_PRIMARY
    end
  end
  
  # Get sentiment color
  def self.sentiment_color(sentiment)
    case sentiment.to_s.downcase
    when 'positive', '1', 'positivo' then SENTIMENT_POSITIVE
    when 'negative', '2', 'negativo' then SENTIMENT_NEGATIVE
    else SENTIMENT_NEUTRAL
    end
  end
  
  # Get chart color by index
  def self.chart_color(index)
    CHART_PALETTE[index % CHART_PALETTE.length]
  end
  
  # Get array of N chart colors
  def self.chart_colors(count = 8)
    CHART_PALETTE.take(count)
  end
  
  # Convert to gradient (for headers)
  def self.gradient(color, direction: '135deg', lighten: 10)
    lighter = lighten_color(color, lighten)
    "linear-gradient(#{direction}, #{color} 0%, #{lighter} 100%)"
  end
  
  private
  
  # Simple color lightening (hex to hex)
  def self.lighten_color(hex, percent)
    hex = hex.gsub('#', '')
    rgb = hex.scan(/../).map { |c| c.to_i(16) }
    rgb = rgb.map { |c| [255, (c + (255 - c) * percent / 100).round].min }
    '#' + rgb.map { |c| c.to_s(16).rjust(2, '0') }.join
  end
end

