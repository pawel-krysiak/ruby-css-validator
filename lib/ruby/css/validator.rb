require 'tempfile'
require 'open3'

module Ruby
  module CSS
    class Validator
      VERSION = '1.0.0'

      # Valid CSS profiles
      VALID_PROFILES = %w[css1 css2 css21 css3 css3svg svg svgbasic svgtiny mobile tv atsc-tv].freeze

      # Valid output formats
      VALID_FORMATS = %w[text json xml html ucn].freeze

      class ValidationResult
        attr_reader :output, :exit_code, :valid, :errors, :warnings, :error_count, :warning_count

        def initialize(output, exit_code)
          @output = output
          @exit_code = exit_code
          @valid = output.include?("Congratulations! No Error Found")
          @errors = extract_errors(output)
          @warnings = extract_warnings(output)
          # If CSS is invalid but no specific errors were extracted, count it as 1 error
          @error_count = !@valid && @errors.empty? ? 1 : @errors.length
          @warning_count = @warnings.length
        end

        def error?
          !@valid
        end

        def warning?
          @warning_count > 0
        end

        # Returns an array of full error messages, similar to Rails ActiveRecord full_messages
        # Example: ["Line 1 (body): Property 'colr' doesn't exist", "Line 2 (.foo): Invalid color"]
        def full_messages
          messages = []

          # Add error messages
          @errors.each do |error|
            if error[:selector] && !error[:selector].empty?
              messages << "Line #{error[:line]} (#{error[:selector]}): #{error[:message]}"
            else
              messages << "Line #{error[:line]}: #{error[:message]}"
            end
          end

          # Add warning messages
          @warnings.each do |warning|
            messages << "Line #{warning[:line]}: #{warning[:message]}"
          end

          # If CSS is invalid but no specific errors/warnings were found, add generic message
          if !@valid && messages.empty?
            messages << "Invalid CSS"
          end

          messages
        end

        private

        def extract_errors(output)
          errors = []

          # Split output into lines and process error sections
          lines = output.split("\n")
          i = 0

          while i < lines.length
            line = lines[i]

            # Look for error lines starting with "Line :" (with or without selector)
            if line =~ /^Line\s*:\s*(\d+)\s*(.*)$/
              line_number = $1.to_i
              selector = $2.strip

              # Collect error message from following lines
              error_message = []
              i += 1

              # Continue reading lines until we hit an empty line or another "Line :" entry
              while i < lines.length && lines[i] !~ /^Line\s*:/ && lines[i] !~ /^URI\s*:/ && lines[i] !~ /^No style sheet/ && lines[i].strip != ""
                error_message << lines[i].strip
                i += 1
              end

              errors << {
                line: line_number,
                selector: selector.empty? ? nil : selector,
                message: error_message.join(" ")
              }

              next
            end

            i += 1
          end

          errors
        end

        def extract_warnings(output)
          warnings = []

          # Find the Warnings section
          if output =~ /Warnings \((\d+)\)/
            lines = output.split("\n")
            in_warnings = false

            lines.each_with_index do |line, i|
              if line =~ /^Warnings \((\d+)\)/
                in_warnings = true
                next
              end

              next unless in_warnings

              # Look for warning lines starting with "Line :"
              if line =~ /^Line\s*:\s*(\d+)\s+(.+)/
                line_number = $1.to_i
                message = $2.strip

                # Get additional warning details from next line if available
                if i + 1 < lines.length && lines[i + 1].strip != "" && lines[i + 1] !~ /^Line\s*:/
                  message += " " + lines[i + 1].strip
                end

                warnings << {
                  line: line_number,
                  message: message
                }
              end

              # Stop at "Valid CSS information" section
              break if line =~ /^Valid CSS information/
            end
          end

          warnings
        end
      end

      def initialize(jar_path: nil)
        @jar_path = jar_path || default_jar_path
        validate_jar_exists!
      end

      # Validate CSS text string
      def validate(css_text, profile: 'css3svg', output_format: 'text')
        raise ArgumentError, "CSS text cannot be nil or empty" if css_text.nil? || css_text.empty?
        validate_profile!(profile)
        validate_output_format!(output_format)

        result = nil

        Tempfile.create(['css_validator', '.css']) do |tempfile|
          tempfile.write(css_text)
          tempfile.flush

          command_array = build_command_array(tempfile.path, profile, output_format)
          stdout, stderr, status = Open3.capture3(*command_array)

          output = stdout + stderr
          result = ValidationResult.new(output, status.exitstatus)
        end

        result
      end

      # Validate CSS file
      def validate_file(file_path, profile: 'css3svg', output_format: 'text')
        raise ArgumentError, "File does not exist: #{file_path}" unless File.exist?(file_path)
        validate_profile!(profile)
        validate_output_format!(output_format)

        command_array = build_command_array(file_path, profile, output_format)
        stdout, stderr, status = Open3.capture3(*command_array)

        output = stdout + stderr
        ValidationResult.new(output, status.exitstatus)
      end

      private

      def default_jar_path
        File.expand_path('../../../../vendor/css-validator.jar', __FILE__)
      end

      def java_opts
        # Memory optimized for CSS validation (~50MB per JVM vs ~75MB default)
        ['-Xmx32m', '-Xms16m', '-XX:+UseSerialGC', '-Xss512k', '-XX:MaxMetaspaceSize=32m']
      end

      def validate_jar_exists!
        unless File.exist?(@jar_path)
          raise "CSS Validator JAR not found at: #{@jar_path}"
        end
      end

      def validate_profile!(profile)
        unless VALID_PROFILES.include?(profile)
          raise ArgumentError, "Invalid profile: #{profile}. Valid profiles are: #{VALID_PROFILES.join(', ')}"
        end
      end

      def validate_output_format!(output_format)
        unless VALID_FORMATS.include?(output_format)
          raise ArgumentError, "Invalid output format: #{output_format}. Valid formats are: #{VALID_FORMATS.join(', ')}"
        end
      end

      def build_command_array(file_path, profile, output_format)
        [
          'java',
          *java_opts,
          '-jar',
          @jar_path,
          "--output=#{output_format}",
          "--profile=#{profile}",
          "file://#{file_path}"
        ]
      end
    end
  end
end
