require_relative 'test_helper'

begin
  require 'active_record'
  require_relative '../lib/ruby/css/active_record'

  # Set up in-memory SQLite database for testing
  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: ':memory:'
  )

  # Create test tables
  ActiveRecord::Schema.define do
    create_table :themes, force: true do |t|
      t.string :name
      t.text :custom_css
      t.text :header_styles
      t.text :optional_css
      t.boolean :css_enabled, default: true
      t.timestamps
    end

    create_table :stylesheets, force: true do |t|
      t.text :content
      t.timestamps
    end

    create_table :advanced_styles, force: true do |t|
      t.text :css_code
      t.timestamps
    end
  end

  # Test model with basic validation
  class Theme < ActiveRecord::Base
    validates_css :custom_css
  end

  # Test model with allow_blank option
  class Stylesheet < ActiveRecord::Base
    validates_css :content, allow_blank: true
  end

  # Test model with multiple validations and options
  class AdvancedStyle < ActiveRecord::Base
    validates_css :css_code,
                  profile: 'css3',
                  full_messages: false,
                  if: :should_validate?

    def should_validate?
      true
    end
  end

  class TestActiveRecord < Minitest::Test
    def setup
      # Clean up before each test
      Theme.delete_all
      Stylesheet.delete_all
      AdvancedStyle.delete_all
    end

    # Basic validation tests
    def test_valid_css_passes_validation
      theme = Theme.new(name: 'Test', custom_css: 'body { color: red; }')
      assert theme.valid?, "Valid CSS should pass validation"
      assert_empty theme.errors[:custom_css]
    end

    def test_invalid_css_fails_validation
      theme = Theme.new(name: 'Test', custom_css: 'body { colr: red; }')
      refute theme.valid?, "Invalid CSS should fail validation"
      assert theme.errors[:custom_css].any?, "Should have errors on custom_css"
    end

    def test_saves_with_valid_css
      theme = Theme.new(name: 'Test', custom_css: 'body { margin: 0; }')
      assert theme.save, "Should save with valid CSS"
      assert_equal 1, Theme.count
    end

    def test_does_not_save_with_invalid_css
      theme = Theme.new(name: 'Test', custom_css: '@@@ invalid @@@')
      refute theme.save, "Should not save with invalid CSS"
      assert_equal 0, Theme.count
      assert theme.errors[:custom_css].any?
    end

    # Error message tests
    def test_error_messages_include_line_numbers
      theme = Theme.new(name: 'Test', custom_css: 'body { colr: red; }')
      theme.valid?

      error_message = theme.errors[:custom_css].first
      assert_match(/Line \d+/, error_message, "Error should include line number")
    end

    def test_error_messages_include_details
      theme = Theme.new(name: 'Test', custom_css: 'body { colr: red; }')
      theme.valid?

      error_message = theme.errors[:custom_css].first.to_s.downcase
      assert_match(/colr|property|doesn't exist/i, error_message, "Error should include details about the issue")
    end

    def test_multiple_errors_for_multiple_issues
      css = <<~CSS
        body {
          colr: red;
          width: -10px;
        }
      CSS

      theme = Theme.new(name: 'Test', custom_css: css)
      theme.valid?

      # Should have multiple error messages
      assert theme.errors[:custom_css].size >= 2, "Should have multiple errors for multiple issues"
    end

    # allow_blank tests
    def test_allow_blank_skips_validation_for_empty_string
      sheet = Stylesheet.new(content: '')
      assert sheet.valid?, "Should be valid with blank content when allow_blank is true"
      assert_empty sheet.errors[:content]
    end

    def test_allow_blank_skips_validation_for_nil
      sheet = Stylesheet.new(content: nil)
      assert sheet.valid?, "Should be valid with nil content when allow_blank is true"
      assert_empty sheet.errors[:content]
    end

    def test_allow_blank_still_validates_non_blank
      sheet = Stylesheet.new(content: 'invalid css @@@')
      refute sheet.valid?, "Should validate non-blank content"
      assert sheet.errors[:content].any?
    end

    # Profile option tests
    def test_validates_with_css3_profile
      style = AdvancedStyle.new(css_code: 'body { color: red; }')
      assert style.valid?, "Should validate with css3 profile"
    end

    # full_messages option tests
    def test_full_messages_false_gives_simple_error
      style = AdvancedStyle.new(css_code: '@@@ invalid @@@')
      refute style.valid?

      # Should have error but not detailed ones
      assert style.errors[:css_code].any?
      # The error should be simpler (just the key)
      assert style.errors.details[:css_code].any?
    end

    # Integration with ActiveRecord lifecycle
    def test_validation_runs_on_create
      theme = Theme.create(name: 'Test', custom_css: 'invalid @@@')
      assert theme.new_record?, "Should not be persisted with invalid CSS"
      assert theme.errors[:custom_css].any?
    end

    def test_validation_runs_on_update
      theme = Theme.create!(name: 'Test', custom_css: 'body { color: red; }')
      theme.custom_css = 'invalid @@@'

      refute theme.save, "Should not save update with invalid CSS"
      assert theme.errors[:custom_css].any?
    end

    def test_update_attributes_respects_validation
      theme = Theme.create!(name: 'Test', custom_css: 'body { color: red; }')

      result = theme.update(custom_css: 'invalid @@@')
      refute result, "update should return false with invalid CSS"
      assert theme.errors[:custom_css].any?
    end

    # Complex CSS tests
    def test_validates_complex_valid_css
      css = <<~CSS
        body {
          margin: 0;
          padding: 0;
          font-family: Arial, sans-serif;
        }

        .container {
          max-width: 1200px;
          margin: 0 auto;
          padding: 20px;
        }

        @media (max-width: 768px) {
          .container {
            padding: 10px;
          }
        }
      CSS

      theme = Theme.new(name: 'Test', custom_css: css)
      assert theme.valid?, "Should validate complex valid CSS"
    end

    def test_validates_css_with_selectors
      css = <<~CSS
        #header { background: blue; }
        .nav-item { display: inline-block; }
        a:hover { color: red; }
      CSS

      theme = Theme.new(name: 'Test', custom_css: css)
      assert theme.valid?, "Should validate CSS with various selectors"
    end

    # Edge cases
    def test_handles_empty_css
      theme = Theme.new(name: 'Test', custom_css: '')
      refute theme.valid?, "Empty CSS should fail validation (no allow_blank)"
      assert theme.errors[:custom_css].any?
    end

    def test_handles_whitespace_only_css
      # W3C validator treats whitespace-only as valid (no CSS = valid CSS)
      # If you want to reject whitespace, use `allow_blank: false` or `presence: true`
      theme = Theme.new(name: 'Test', custom_css: "   \n\t   ")
      assert theme.valid?, "Whitespace-only CSS is considered valid by W3C validator"
      assert_empty theme.errors[:custom_css]
    end

    def test_handles_very_long_css
      # Generate a long but valid CSS
      css = (1..50).map { |i| ".class-#{i} { color: red; }" }.join("\n")

      theme = Theme.new(name: 'Test', custom_css: css)
      assert theme.valid?, "Should handle long CSS"
    end

    # Multiple attribute validation
    def test_validates_multiple_attributes
      # Create a model that validates multiple CSS attributes
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = 'themes'
        validates_css :custom_css, :header_styles
      end

      instance = klass.new(
        name: 'Test',
        custom_css: 'body { color: red; }',
        header_styles: 'invalid @@@'
      )

      refute instance.valid?
      assert_empty instance.errors[:custom_css]
      assert instance.errors[:header_styles].any?
    end

    # Test that validator doesn't interfere with other validations
    def test_works_with_other_validations
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = 'themes'

        def self.name
          'TempModel'
        end

        validates :name, presence: true
        validates_css :custom_css
      end

      instance = klass.new(custom_css: 'body { color: red; }')
      refute instance.valid?
      assert instance.errors[:name].any?
      assert_empty instance.errors[:custom_css]
    end

    def test_all_validations_can_fail
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = 'themes'

        def self.name
          'TempModel2'
        end

        validates :name, presence: true
        validates_css :custom_css
      end

      instance = klass.new(custom_css: 'invalid @@@')
      refute instance.valid?
      assert instance.errors[:name].any?
      assert instance.errors[:custom_css].any?
    end

    # Conditional validation tests
    def test_conditional_validation_with_if
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = 'themes'
        validates_css :custom_css, if: :css_enabled?
      end

      # When condition is true
      instance = klass.new(custom_css: 'invalid @@@', css_enabled: true)
      refute instance.valid?
      assert instance.errors[:custom_css].any?

      # When condition is false
      instance = klass.new(custom_css: 'invalid @@@', css_enabled: false)
      assert instance.valid?
      assert_empty instance.errors[:custom_css]
    end

    def test_conditional_validation_with_unless
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = 'themes'
        validates_css :custom_css, unless: -> { name.blank? }
      end

      # When condition is true (has name, so validate)
      instance = klass.new(name: 'Test', custom_css: 'invalid @@@')
      refute instance.valid?
      assert instance.errors[:custom_css].any?

      # When condition is false (no name, so skip validation)
      instance = klass.new(name: nil, custom_css: 'invalid @@@')
      assert instance.valid?
      assert_empty instance.errors[:custom_css]
    end
  end

  puts "ActiveRecord tests loaded successfully"

rescue LoadError => e
  puts "Skipping ActiveRecord tests: #{e.message}"
  puts "Run 'bundle install' to install ActiveRecord and SQLite3"
end
