#!/usr/bin/env ruby

require_relative 'test_helper'
require 'ruby-css-validator'

puts "=" * 70
puts "Testing Detailed Error Extraction"
puts "=" * 70
puts

# Test 1: Missing value error
puts "Test 1: Missing property value"
puts "-" * 70
result = RubyCssValidator.validate("body { color: }")
puts "Valid: #{result.valid}"
puts "Error count: #{result.error_count}"
puts "Errors:"
result.errors.each do |error|
  puts "  Line #{error[:line]}: #{error[:selector]}"
  puts "  Message: #{error[:message]}"
end
puts

# Test 2: Misspelled property
puts "Test 2: Misspelled property"
puts "-" * 70
result = RubyCssValidator.validate("body { colr: red; }")
puts "Valid: #{result.valid}"
puts "Error count: #{result.error_count}"
puts "Errors:"
result.errors.each do |error|
  puts "  Line #{error[:line]}: #{error[:selector]}"
  puts "  Message: #{error[:message]}"
end
puts

# Test 3: Multiple errors
puts "Test 3: Multiple errors"
puts "-" * 70
css = <<~CSS
  body {
    colr: red;
    background-color: #GGG;
    margin: 10px 20px 30px 40px 50px;
  }
CSS
result = RubyCssValidator.validate(css)
puts "Valid: #{result.valid}"
puts "Error count: #{result.error_count}"
puts "Errors:"
result.errors.each do |error|
  puts "  Line #{error[:line]}: #{error[:selector]}"
  puts "  Message: #{error[:message]}"
end
puts

# Test 4: Warning
puts "Test 4: Out of range RGB (warning)"
puts "-" * 70
result = RubyCssValidator.validate("body { color: rgb(300, 100, 50); }")
puts "Valid: #{result.valid}"
puts "Warning count: #{result.warning_count}"
puts "Warnings:"
result.warnings.each do |warning|
  puts "  Line #{warning[:line]}: #{warning[:message]}"
end
puts

# Test 5: Valid CSS
puts "Test 5: Valid CSS"
puts "-" * 70
result = RubyCssValidator.validate("body { color: red; margin: 10px; }")
puts "Valid: #{result.valid}"
puts "Error count: #{result.error_count}"
puts "Warning count: #{result.warning_count}"
puts

puts "=" * 70
puts "All tests completed!"
puts "=" * 70
