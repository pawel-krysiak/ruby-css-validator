#!/usr/bin/env ruby
# Quick test script to verify the gem works

require_relative 'test_helper'
require 'ruby-css-validator'

puts "=" * 70
puts "Testing Ruby CSS Validator Gem"
puts "=" * 70
puts

# Test 1: Quick validation
puts "Test 1: Quick validation of valid CSS"
result = RubyCssValidator.validate("body { color: red; }")
puts "Valid: #{result.valid}"
puts "Error count: #{result.error_count}"
puts

# Test 2: Invalid CSS
puts "Test 2: Validation of invalid CSS"
result = RubyCssValidator.validate("body { color: }")
puts "Valid: #{result.valid}"
puts "Error count: #{result.error_count}"
puts "Has errors: #{result.error?}"
puts "Error details:"
result.errors.each do |error|
  puts "  Line #{error[:line]}: #{error[:message]}"
end
puts

# Test 3: Using validator instance
puts "Test 3: Using validator instance"
validator = RubyCssValidator.new
result = validator.validate("body { colr: red; }")
puts "Valid: #{result.valid}"
puts "Exit code: #{result.exit_code}"
puts

# Test 4: Custom profile
puts "Test 4: Validation with CSS3 profile"
result = validator.validate("body { display: flex; }", profile: 'css3')
puts "Valid: #{result.valid}"
puts

# Test 5: Multiple invalid properties
puts "Test 5: Multiple test cases"
test_cases = [
  { css: "body { color: red; }", expected: true },
  { css: "body { color: }", expected: false },
  { css: "body { margin: 10px 20px 30px 40px 50px; }", expected: false },
  { css: ".class { background-color: #GGG; }", expected: false }
]

test_cases.each_with_index do |test, i|
  result = validator.validate(test[:css])
  status = result.valid == test[:expected] ? "✅ PASS" : "❌ FAIL"
  puts "  #{status} - Test #{i + 1}: Valid=#{result.valid}, Expected=#{test[:expected]}"
end

puts
puts "=" * 70
puts "All tests completed!"
puts "=" * 70
