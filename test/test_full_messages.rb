#!/usr/bin/env ruby

require_relative 'test_helper'
require 'ruby-css-validator'

puts "=" * 70
puts "Testing full_messages Method"
puts "=" * 70
puts

# Test 1: Single error
puts "Test 1: Single error"
puts "-" * 70
result = RubyCssValidator.validate("body { color: }")
puts "Full messages:"
result.full_messages.each do |msg|
  puts "  - #{msg}"
end
puts

# Test 2: Multiple errors
puts "Test 2: Multiple errors"
puts "-" * 70
css = <<~CSS
  body {
    colr: red;
    background-color: #GGG;
    margin: 10px 20px 30px 40px 50px;
  }
CSS
result = RubyCssValidator.validate(css)
puts "Full messages:"
result.full_messages.each do |msg|
  puts "  - #{msg}"
end
puts

# Test 3: Warning
puts "Test 3: Warning (out of range RGB)"
puts "-" * 70
result = RubyCssValidator.validate("body { color: rgb(300, 100, 50); }")
puts "Full messages:"
result.full_messages.each do |msg|
  puts "  - #{msg}"
end
puts

# Test 4: Valid CSS (no messages)
puts "Test 4: Valid CSS (no messages)"
puts "-" * 70
result = RubyCssValidator.validate("body { color: red; margin: 10px; }")
puts "Full messages: #{result.full_messages.inspect}"
puts "Empty? #{result.full_messages.empty?}"
puts

# Test 5: Display all messages in one go (like showing to user)
puts "Test 5: Display all messages as a single string"
puts "-" * 70
css_with_errors = "body { colr: red; width: -10px; }"
result = RubyCssValidator.validate(css_with_errors)
if result.error?
  puts "CSS Validation Failed:"
  puts result.full_messages.join("\n")
end
puts

puts "=" * 70
puts "All tests completed!"
puts "=" * 70
