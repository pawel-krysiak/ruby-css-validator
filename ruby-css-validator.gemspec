Gem::Specification.new do |spec|
  spec.name          = "ruby-css-validator"
  spec.version       = "1.0.0"
  spec.authors       = ["CSS Validator Team"]
  spec.email         = ["noreply@example.com"]

  spec.summary       = %q{Ruby wrapper for W3C CSS Validator}
  spec.description   = %q{A Ruby gem that wraps the W3C CSS Validator JAR file, providing an easy-to-use interface for validating CSS code and files.}
  spec.homepage      = "https://github.com/pawel-krysiak/ruby-css-validator"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/pawel-krysiak/ruby-css-validator"
  spec.metadata["changelog_uri"] = "https://github.com/pawel-krysiak/ruby-css-validator/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob([
    "lib/**/*",
    "vendor/**/*",
    "README.md",
    "LICENSE",
    "CHANGELOG.md"
  ]).reject { |f| File.directory?(f) }

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  # No additional dependencies needed - uses only Ruby stdlib

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "get_process_mem", "~> 1.0"
  spec.add_development_dependency "activerecord", ">= 6.0"
  spec.add_development_dependency "sqlite3", "~> 2.1"
end
