require_relative 'ruby/css/validator'

# Load ActiveRecord integration if ActiveRecord is available
begin
  require 'active_record'
  require_relative 'ruby/css/active_record'
rescue LoadError
  # ActiveRecord not available, skip integration
end

module RubyCssValidator
  # Convenience method to create a validator instance
  def self.new(jar_path: nil)
    Ruby::CSS::Validator.new(jar_path: jar_path)
  end

  # Quick validation method
  def self.validate(css_text, **options)
    validator = Ruby::CSS::Validator.new
    validator.validate(css_text, **options)
  end

  # Quick file validation method
  def self.validate_file(file_path, **options)
    validator = Ruby::CSS::Validator.new
    validator.validate_file(file_path, **options)
  end
end
