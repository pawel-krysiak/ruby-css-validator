#!/usr/bin/env ruby

require_relative 'test_helper'
require 'ruby-css-validator'

puts "=" * 70
puts "Testing Invalid CSS Handling"
puts "=" * 70
puts

# Test 1: Completely invalid CSS
puts "Test 1: Completely invalid text"
puts "-" * 70
result = RubyCssValidator.validate("this is not css at all!!!")
puts "Valid: #{result.valid}"
puts "Error count: #{result.error_count}"
puts "Errors: #{result.errors.inspect}"
puts "Full messages:"
result.full_messages.each { |msg| puts "  - #{msg}" }
puts

# Test 2: Empty braces
puts "Test 2: Just random characters"
puts "-" * 70
result = RubyCssValidator.validate("@@@###$$$")
puts "Valid: #{result.valid}"
puts "Error count: #{result.error_count}"
puts "Full messages:"
result.full_messages.each { |msg| puts "  - #{msg}" }
puts

# Test 3: Valid CSS (should have no messages)
puts "Test 3: Valid CSS"
puts "-" * 70
result = RubyCssValidator.validate("body { color: red; }")
puts "Valid: #{result.valid}"
puts "Error count: #{result.error_count}"
puts "Full messages: #{result.full_messages.inspect}"
puts

# Test 4: CSS with property errors
puts "Test 4: CSS with property errors"
puts "-" * 70
result = RubyCssValidator.validate("body { colr: red; width: -10px; }")
puts "Valid: #{result.valid}"
puts "Error count: #{result.error_count}"
puts "Full messages:"
result.full_messages.each { |msg| puts "  - #{msg}" }
puts

# Test 5: Display to user (real-world usage)
puts "Test 5: Display to user (real-world usage)"
puts "-" * 70
css_input = "@@@ invalid css @@@"
result = RubyCssValidator.validate(css_input)
if result.error?
  puts "CSS Validation Failed:"
  puts result.full_messages.join("\n")
else
  puts "CSS is valid!"
end
puts

puts "=" * 70
puts "All tests completed!"
puts "=" * 70
