# Ruby CSS Validator

A Ruby gem that wraps the W3C CSS Validator, providing an easy-to-use interface for validating CSS code and files. This gem runs the validator **locally** on your machine using the official W3C CSS Validator JAR file from https://jigsaw.w3.org/css-validator/DOWNLOAD.html - no external API calls or internet connection required for validation.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby-css-validator', git: 'https://github.com/pawel-krysiak/ruby-css-validator.git'
```

And then execute:

    $ bundle install

Or build and install from source:

    $ git clone https://github.com/pawel-krysiak/ruby-css-validator.git
    $ cd ruby-css-validator
    $ gem build ruby-css-validator.gemspec
    $ gem install ./ruby-css-validator-1.0.0.gem

## Requirements

- Ruby >= 2.7.0
- Java Runtime Environment (JRE) installed on your system

To install Java on Ubuntu/Debian:

    $ sudo apt install default-jre

To verify Java is installed:

    $ java -version


## Usage

### Quick Validation

```ruby
require 'ruby-css-validator'

# Validate CSS text
result = RubyCssValidator.validate("body { color: red; }")

if result.valid
  puts "CSS is valid!"
else
  puts "CSS has #{result.error_count} error(s)"
end
```

### Using the Validator Class

```ruby
require 'ruby-css-validator'

validator = RubyCssValidator.new

# Validate CSS text
result = validator.validate("body { color: red; }")

puts "Valid: #{result.valid}"
puts "Errors: #{result.errors}"
puts "Warnings: #{result.warnings}"
puts "Exit code: #{result.exit_code}"
puts "Full output:\n#{result.output}"
```

### Validate CSS Files

```ruby
result = RubyCssValidator.validate_file("path/to/style.css")

if result.error?
  puts "Validation failed with #{result.errors} errors"
end
```

### Custom Options

```ruby
# Validate against specific CSS profile
result = validator.validate(css_text, profile: 'css3')

# Available profiles: css1, css2, css21, css3, css3svg, svg, svgbasic, svgtiny, mobile, tv, atsc-tv
# Invalid profiles will raise an ArgumentError

# Different output format
result = validator.validate(css_text, output_format: 'json')
```

### Custom JAR Path

```ruby
validator = RubyCssValidator.new(jar_path: '/custom/path/css-validator.jar')
```

## Performance

The gem automatically optimizes JVM memory usage for CSS validation:

**Memory footprint:**
- Single validation: ~120 MB total (~50MB JVM + 50MB Ruby)
- 10 parallel validations: ~685 MB total (~68 MB per thread)
- Each JVM process: ~50 MB (optimized with `-Xmx32m -Xms16m -XX:+UseSerialGC`)

**Speed:**
- Validation time: ~100-200ms per CSS file (includes JVM startup)
- Parallel speedup: ~9x with 10 concurrent threads

## ActiveRecord/Rails Integration

Validate CSS directly in your ActiveRecord models:

```ruby
class Theme < ApplicationRecord
  validates_css :custom_css
end

theme = Theme.new(custom_css: 'body { colr: red; }')
theme.valid?  # => false
theme.errors[:custom_css]
# => ["Line 1 (body): Property \"colr\" doesn't exist..."]
```

### Options

```ruby
class Stylesheet < ApplicationRecord
  validates_css :content, allow_blank: true           # Skip if blank
  validates_css :styles, profile: 'css3'              # Specific CSS version
  validates_css :theme_css, if: :css_enabled?         # Conditional
  validates_css :custom, message: "must be valid CSS" # Custom message
end
```

**Available options:**
- `:profile` - CSS profile (`css1`, `css2`, `css21`, `css3`, `css3svg`, `svg`, etc.) - default: `css3svg`
- `:allow_blank`, `:allow_nil` - Skip validation for blank/nil values
- `:message` - Custom error message
- `:full_messages` - Include detailed errors (default: `true`)
- `:if`, `:unless`, `:on` - Standard ActiveRecord validation options

**Run tests:**
```bash
rake test_active_record
```

## ValidationResult Object

The `validate` and `validate_file` methods return a `ValidationResult` object with the following attributes:

- `valid` - Boolean indicating if CSS is valid
- `errors` - Array of error hashes with `:line`, `:selector`, and `:message` keys
- `warnings` - Array of warning hashes with `:line` and `:message` keys
- `error_count` - Number of errors found
- `warning_count` - Number of warnings found
- `exit_code` - Exit code from validator (0 = success, 11 = 1 error, etc.)
- `output` - Full validation output text
- `error?` - Returns true if there are errors
- `warning?` - Returns true if there are warnings
- `full_messages` - Returns an array of human-readable error/warning messages (similar to Rails ActiveRecord)

### Example: Accessing Detailed Error Information

```ruby
result = RubyCssValidator.validate("body { colr: red; width: -10px; }")

if result.error?
  puts "Found #{result.error_count} error(s):"
  result.errors.each do |error|
    puts "  Line #{error[:line]}: #{error[:selector]}"
    puts "  #{error[:message]}"
  end
end

# Output:
# Found 2 error(s):
#   Line 1: body
#   Property "colr" doesn't exist. The closest matching property name is "color" : red
#   Line 1: body
#   "-10px" negative values are not allowed :
```

### Example: Using full_messages (Rails-style)

```ruby
result = RubyCssValidator.validate("body { colr: red; width: -10px; }")

if result.error?
  puts "CSS Validation Failed:"
  puts result.full_messages.join("\n")
end

# Output:
# CSS Validation Failed:
# Line 1 (body): Property "colr" doesn't exist. The closest matching property name is "color" : red
# Line 1 (body): "-10px" negative values are not allowed :
```

This is especially useful for displaying errors to users in web applications, similar to how Rails displays ActiveRecord validation errors.

**Note:** When CSS is completely invalid (unparseable), the gem will still extract parse errors and return them in `full_messages`. If for any reason no specific errors can be extracted but the CSS is invalid, `full_messages` will return `["Invalid CSS"]` to ensure you always have a message to display to users.

```ruby
# Completely invalid CSS
result = RubyCssValidator.validate("@@@ not css @@@")
puts result.full_messages.first
# => "Line 0: Parse Error Lexical error..."

# Always guaranteed to have at least one error message when invalid
result.error_count  # => 1 (minimum when CSS is invalid)
```

## Development

After checking out the repo, run `bundle install` to install dependencies.

To build the gem:

    $ gem build ruby-css-validator.gemspec

To install the gem locally:

    $ gem install ./ruby-css-validator-1.0.0.gem

### Running Tests

    $ ruby test/test_gem.rb

### Performance Tests

To measure memory usage and execution speed:

    $ ruby test/test_performance.rb

For detailed performance analysis and optimization strategies, see [PERFORMANCE.md](PERFORMANCE.md).

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The Ruby wrapper code is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

The bundled W3C CSS Validator JAR file is licensed under the [W3C Software and Document License (2023)](https://www.w3.org/copyright/software-license-2023/).

See the [LICENSE](LICENSE) file for full details.

## Important Notes

- **W3C Logo**: Download and use of this software does NOT grant permission to display the W3C logo. Use of the W3C logo requires prior approval from the W3C Team (site-policy@w3.org).
- **Java Required**: This gem requires Java Runtime Environment (JRE) to be installed on your system.
- **Validation Service**: This gem runs the validator locally. It does not send CSS to W3C's online validation service.

## Credits

This gem wraps the [W3C CSS Validator](https://jigsaw.w3.org/css-validator/) developed by the W3C.

Copyright © W3C® (MIT, ERCIM, Keio, Beihang)
