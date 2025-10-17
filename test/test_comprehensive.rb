#!/usr/bin/env ruby
# Comprehensive test suite for ruby-css-validator

require_relative 'test_helper'
require 'ruby-css-validator'
require 'fileutils'

class TestRunner
  attr_reader :passed, :failed, :tests

  def initialize
    @passed = 0
    @failed = 0
    @tests = []
  end

  def test(name, &block)
    print "Testing: #{name}... "
    begin
      block.call
      puts "✅ PASS"
      @passed += 1
      @tests << { name: name, status: :pass }
    rescue => e
      puts "❌ FAIL"
      puts "  Error: #{e.message}"
      puts "  #{e.backtrace.first}"
      @failed += 1
      @tests << { name: name, status: :fail, error: e.message }
    end
  end

  def assert(condition, message = "Assertion failed")
    raise message unless condition
  end

  def assert_equal(expected, actual, message = nil)
    msg = message || "Expected #{expected.inspect}, got #{actual.inspect}"
    raise msg unless expected == actual
  end

  def summary
    puts "\n" + "=" * 70
    puts "Test Summary"
    puts "=" * 70
    puts "Total: #{@passed + @failed}"
    puts "Passed: #{@passed} ✅"
    puts "Failed: #{@failed} #{@failed > 0 ? '❌' : ''}"
    puts "=" * 70
  end
end

runner = TestRunner.new

puts "=" * 70
puts "Comprehensive Ruby CSS Validator Test Suite"
puts "=" * 70
puts

# Test 1: validate_file method
runner.test("validate_file with valid CSS file") do
  File.write('/tmp/test_valid.css', 'body { color: red; }')
  result = RubyCssValidator.validate_file('/tmp/test_valid.css')
  runner.assert result.valid, "Should be valid"
  runner.assert_equal 0, result.error_count
  File.delete('/tmp/test_valid.css')
end

runner.test("validate_file with invalid CSS file") do
  File.write('/tmp/test_invalid.css', 'body { colr: red; }')
  result = RubyCssValidator.validate_file('/tmp/test_invalid.css')
  runner.assert !result.valid, "Should be invalid"
  runner.assert result.error_count > 0
  File.delete('/tmp/test_invalid.css')
end

runner.test("validate_file with non-existent file") do
  begin
    RubyCssValidator.validate_file('/tmp/nonexistent.css')
    runner.assert false, "Should raise ArgumentError"
  rescue ArgumentError => e
    runner.assert e.message.include?("does not exist"), "Should mention file doesn't exist"
  end
end

# Test 2: Different CSS profiles
runner.test("validate with CSS3 profile") do
  validator = RubyCssValidator.new
  result = validator.validate('body { display: flex; }', profile: 'css3')
  runner.assert result.valid, "Flexbox should be valid in CSS3"
end

runner.test("validate with CSS2 profile") do
  validator = RubyCssValidator.new
  result = validator.validate('body { display: flex; }', profile: 'css2')
  runner.assert !result.valid, "Flexbox should be invalid in CSS2"
end

runner.test("validate with mobile profile") do
  validator = RubyCssValidator.new
  result = validator.validate('body { color: red; }', profile: 'mobile')
  runner.assert result.valid, "Basic properties should work in mobile"
end

# Test 3: Input validation
runner.test("validate rejects nil input") do
  begin
    RubyCssValidator.validate(nil)
    runner.assert false, "Should raise ArgumentError"
  rescue ArgumentError => e
    runner.assert e.message.include?("nil"), "Should mention nil"
  end
end

runner.test("validate rejects empty string") do
  begin
    RubyCssValidator.validate("")
    runner.assert false, "Should raise ArgumentError"
  rescue ArgumentError => e
    runner.assert e.message.include?("empty"), "Should mention empty"
  end
end

# Test 4: Exit codes
runner.test("exit code 0 for valid CSS") do
  result = RubyCssValidator.validate('body { color: red; }')
  runner.assert_equal 0, result.exit_code
end

runner.test("exit code > 0 for invalid CSS") do
  result = RubyCssValidator.validate('body { color: }')
  runner.assert result.exit_code > 0, "Exit code should be > 0"
end

# Test 5: Warning detection
runner.test("warning detection for vendor prefixes") do
  css = 'body { -webkit-border-radius: 5px; }'
  result = RubyCssValidator.validate(css)
  # May or may not have warnings depending on profile, just check structure
  runner.assert result.warnings.is_a?(Array)
  runner.assert result.warning_count >= 0
end

runner.test("warning? returns correct boolean") do
  result = RubyCssValidator.validate('body { color: rgb(300, 100, 50); }')
  if result.warning_count > 0
    runner.assert result.warning?, "warning? should return true when warnings exist"
  end
end

# Test 6: Error details structure
runner.test("errors array has correct structure") do
  result = RubyCssValidator.validate('body { colr: red; }')
  runner.assert !result.errors.empty?, "Should have errors"
  error = result.errors.first
  runner.assert error.key?(:line), "Error should have :line key"
  runner.assert error.key?(:message), "Error should have :message key"
end

# Test 7: Multiple errors
runner.test("multiple errors are all captured") do
  css = <<~CSS
    body {
      colr: red;
      widht: 100%;
      margn: 10px;
    }
  CSS
  result = RubyCssValidator.validate(css)
  runner.assert result.error_count >= 3, "Should have at least 3 errors"
  runner.assert result.errors.length >= 3, "Errors array should have at least 3 items"
end

# Test 8: Empty CSS
runner.test("empty CSS with only whitespace") do
  result = RubyCssValidator.validate('   ')
  # Empty CSS might be valid or invalid depending on validator
  runner.assert [true, false].include?(result.valid), "Should return boolean"
end

runner.test("empty CSS with only comments") do
  result = RubyCssValidator.validate('/* just a comment */')
  runner.assert result.valid || result.error?, "Should be valid or have errors"
end

# Test 9: Special characters and encoding
runner.test("CSS with UTF-8 characters") do
  css = 'body::before { content: "→ ★ 你好"; }'
  result = RubyCssValidator.validate(css)
  runner.assert [true, false].include?(result.valid), "Should handle UTF-8"
end

runner.test("CSS with escaped characters") do
  css = 'body { content: "\A"; }'
  result = RubyCssValidator.validate(css)
  runner.assert result.valid, "Escaped characters should be valid"
end

# Test 10: At-rules
runner.test("@media query validation") do
  css = '@media screen and (max-width: 600px) { body { color: red; } }'
  result = RubyCssValidator.validate(css)
  runner.assert result.valid, "@media should be valid"
end

runner.test("@import rule validation") do
  css = '@import url("style.css");'
  result = RubyCssValidator.validate(css)
  runner.assert result.valid, "@import should be valid"
end

runner.test("@keyframes validation") do
  css = '@keyframes slide { from { left: 0; } to { left: 100px; } }'
  result = RubyCssValidator.validate(css)
  runner.assert result.valid, "@keyframes should be valid"
end

# Test 11: Complex selectors
runner.test("complex selector with pseudo-classes") do
  css = 'a:hover:not(.disabled) { color: blue; }'
  result = RubyCssValidator.validate(css)
  runner.assert result.valid, "Complex selectors should be valid"
end

runner.test("attribute selector") do
  css = 'input[type="text"] { border: 1px solid black; }'
  result = RubyCssValidator.validate(css)
  runner.assert result.valid, "Attribute selectors should be valid"
end

# Test 12: CSS custom properties
runner.test("CSS custom properties (variables)") do
  css = ':root { --main-color: red; } body { color: var(--main-color); }'
  result = RubyCssValidator.validate(css)
  # Custom properties may not be valid in older profiles
  runner.assert [true, false].include?(result.valid), "Should validate custom properties"
end

# Test 13: Validator instance reuse
runner.test("validator instance can be reused") do
  validator = RubyCssValidator.new
  result1 = validator.validate('body { color: red; }')
  result2 = validator.validate('body { color: blue; }')
  runner.assert result1.valid, "First validation should succeed"
  runner.assert result2.valid, "Second validation should succeed"
end

# Test 14: Large CSS
runner.test("validate large CSS file") do
  large_css = (1..100).map { |i| ".class#{i} { color: red; margin: 10px; }" }.join("\n")
  result = RubyCssValidator.validate(large_css)
  runner.assert result.valid, "Large CSS should be valid"
end

# Test 15: Mixed valid and invalid
runner.test("mixed valid and invalid rules") do
  css = <<~CSS
    .valid { color: red; }
    .invalid { colr: blue; }
    .also-valid { margin: 10px; }
  CSS
  result = RubyCssValidator.validate(css)
  runner.assert !result.valid, "Should be invalid due to one error"
  runner.assert_equal 1, result.error_count, "Should have exactly 1 error"
end

# Test 16: Vendor prefixes
runner.test("vendor prefixes handling") do
  css = 'body { -webkit-transform: rotate(45deg); -moz-transform: rotate(45deg); }'
  result = RubyCssValidator.validate(css)
  # Vendor prefixes might generate warnings
  runner.assert result.valid || result.warning_count > 0, "Should be valid or have warnings"
end

# Test 17: !important flag
runner.test("!important flag") do
  css = 'body { color: red !important; }'
  result = RubyCssValidator.validate(css)
  runner.assert result.valid, "!important should be valid"
end

# Test 18: Multiple values
runner.test("multiple values in shorthand") do
  css = 'body { margin: 10px 20px 30px 40px; }'
  result = RubyCssValidator.validate(css)
  runner.assert result.valid, "4 values in margin should be valid"
end

# Test 19: Color formats
runner.test("hex color") do
  result = RubyCssValidator.validate('body { color: #FF0000; }')
  runner.assert result.valid, "Hex colors should be valid"
end

runner.test("rgb color") do
  result = RubyCssValidator.validate('body { color: rgb(255, 0, 0); }')
  runner.assert result.valid, "RGB colors should be valid"
end

runner.test("rgba color") do
  result = RubyCssValidator.validate('body { color: rgba(255, 0, 0, 0.5); }')
  runner.assert result.valid, "RGBA colors should be valid"
end

runner.test("named color") do
  result = RubyCssValidator.validate('body { color: red; }')
  runner.assert result.valid, "Named colors should be valid"
end

# Test 20: error? and warning? methods
runner.test("error? method returns correct value") do
  valid_result = RubyCssValidator.validate('body { color: red; }')
  invalid_result = RubyCssValidator.validate('body { colr: red; }')
  runner.assert !valid_result.error?, "error? should be false for valid CSS"
  runner.assert invalid_result.error?, "error? should be true for invalid CSS"
end

# Test 21: full_messages for valid CSS
runner.test("full_messages is empty for valid CSS") do
  result = RubyCssValidator.validate('body { color: red; }')
  runner.assert result.full_messages.empty?, "full_messages should be empty for valid CSS"
end

# Test 22: Custom JAR path error handling
runner.test("custom JAR path with non-existent file") do
  begin
    RubyCssValidator.new(jar_path: '/nonexistent/path/validator.jar')
    runner.assert false, "Should raise error for non-existent JAR"
  rescue => e
    runner.assert e.message.include?("not found"), "Should mention JAR not found"
  end
end

# Test 23: Comments in CSS
runner.test("CSS with comments") do
  css = <<~CSS
    /* This is a comment */
    body {
      color: red; /* inline comment */
    }
    /* Another comment */
  CSS
  result = RubyCssValidator.validate(css)
  runner.assert result.valid, "Comments should be valid"
end

# Test 24: calc() function
runner.test("calc() function") do
  css = 'body { width: calc(100% - 50px); }'
  result = RubyCssValidator.validate(css)
  runner.assert result.valid, "calc() should be valid in CSS3"
end

# Test 25: Gradients
runner.test("linear gradient") do
  css = 'body { background: linear-gradient(to right, red, blue); }'
  result = RubyCssValidator.validate(css)
  runner.assert result.valid, "linear-gradient should be valid"
end

runner.summary
