# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-17

### Added
- Initial release of ruby-css-validator gem
- Ruby wrapper for W3C CSS Validator JAR file
- `validate` method for validating CSS text strings
- `validate_file` method for validating CSS files
- `ValidationResult` object with detailed validation information
- Support for custom CSS profiles (css1, css2, css21, css3, css3svg, svg, svgbasic, svgtiny, mobile, tv, atsc-tv)
- Support for different output formats (text, json, xml, html, ucn)
- Input validation for CSS profile and output format parameters with whitelist approach
- `VALID_PROFILES` constant listing all supported CSS profiles
- `VALID_FORMATS` constant listing all supported output formats
- ActiveRecord/ActiveModel integration with `validates_css` helper
- Detailed error messages with line numbers and selectors
- Rails-style `full_messages` for user-friendly error display
- Array-based command execution for security (prevents command injection)
- Comprehensive test suite with 40+ test cases
- ActiveRecord integration tests with 25+ test cases
- Bundled W3C CSS Validator JAR file (version from 2024)
- Comprehensive README with usage examples
- MIT License

### Requirements
- Ruby >= 2.7.0
- Java Runtime Environment (JRE)
