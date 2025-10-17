require 'active_model'

module Ruby
  module CSS
    # ActiveRecord/ActiveModel validator for CSS validation
    #
    # Usage:
    #   class Theme < ApplicationRecord
    #     validates :custom_css, css: true
    #   end
    #
    # With options:
    #   validates :styles, css: { profile: 'css3', allow_blank: true }
    class CssValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        return if value.blank? && options[:allow_blank]
        return if value.nil? && options[:allow_nil]

        begin
          validator = Ruby::CSS::Validator.new
          profile = options[:profile] || 'css3svg'
          result = validator.validate(value, profile: profile)

          unless result.valid
            # Add errors to the record
            if options[:message]
              # Custom message
              record.errors.add(attribute, options[:message])
            elsif options[:full_messages] == false
              # Just add "is invalid"
              record.errors.add(attribute, :invalid_css)
            else
              # Add detailed errors (default behavior)
              result.errors.each do |error|
                message = if error[:selector] && !error[:selector].empty?
                  "Line #{error[:line]} (#{error[:selector]}): #{error[:message]}"
                else
                  "Line #{error[:line]}: #{error[:message]}"
                end
                record.errors.add(attribute, message)
              end

              # If no specific errors but CSS is invalid, add generic message
              if result.errors.empty?
                record.errors.add(attribute, "contains invalid CSS")
              end
            end
          end
        rescue => e
          # Handle validation errors gracefully
          record.errors.add(attribute, "validation failed: #{e.message}")
        end
      end
    end

    # Module to include in ActiveRecord models for convenient CSS validation
    module ActiveRecordHelper
      extend ActiveSupport::Concern

      class_methods do
        # Validates that the specified attributes contain valid CSS
        #
        # Options:
        #   :profile - CSS profile to validate against (default: 'css3svg')
        #              Available: css1, css2, css21, css3, css3svg, svg, svgbasic, svgtiny, mobile, tv, atsc-tv
        #   :allow_blank - Skip validation if value is blank (default: false)
        #   :allow_nil - Skip validation if value is nil (default: false)
        #   :message - Custom error message (overrides detailed errors)
        #   :full_messages - Include detailed error messages (default: true)
        #   :on - Validation context (:create, :update, or :save)
        #   :if - Conditional validation (proc or symbol)
        #   :unless - Conditional validation (proc or symbol)
        #
        # Examples:
        #   validates_css :custom_css
        #   validates_css :theme_styles, profile: 'css3', allow_blank: true
        #   validates_css :styles, message: "must be valid CSS"
        #   validates_css :css_code, if: :css_enabled?
        def validates_css(*attr_names)
          validates_with CssValidator, _merge_attributes(attr_names)
        end
      end
    end
  end
end

# Auto-include in ActiveRecord if it's available
if defined?(ActiveRecord::Base)
  ActiveRecord::Base.include(Ruby::CSS::ActiveRecordHelper)
end
