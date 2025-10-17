require_relative 'test_helper'
require 'benchmark'
require 'json'

# Optional performance gems - provide better measurements if available
begin
  require 'get_process_mem'
  GET_PROCESS_MEM_AVAILABLE = true
rescue LoadError
  GET_PROCESS_MEM_AVAILABLE = false
end

begin
  require 'benchmark/memory'
  BENCHMARK_MEMORY_AVAILABLE = true
rescue LoadError
  BENCHMARK_MEMORY_AVAILABLE = false
end

# Performance test suite for CSS Validator
# Tests memory usage and execution speed when running the Java JAR file
class TestPerformance < Minitest::Test
  SMALL_CSS = "body { color: red; }"

  MEDIUM_CSS = <<~CSS
    body {
      margin: 0;
      padding: 0;
      font-family: Arial, sans-serif;
    }
    .container {
      max-width: 1200px;
      margin: 0 auto;
    }
    .header {
      background: #333;
      color: white;
      padding: 20px;
    }
    .content {
      padding: 40px 20px;
    }
    .footer {
      background: #f5f5f5;
      padding: 20px;
      text-align: center;
    }
  CSS

  LARGE_CSS = (1..100).map { |i|
    ".class-#{i} { color: ##{i.to_s.rjust(6, '0')}; margin: #{i}px; padding: #{i}px; }"
  }.join("\n")

  def setup
    @validator = RubyCssValidator.new
    # Warmup: run once to ensure JAR is cached by OS
    @validator.validate(SMALL_CSS) rescue nil
  end

  # Helper method to get current process memory usage in MB
  def get_memory_usage
    # Prefer get_process_mem gem if available (most accurate)
    if GET_PROCESS_MEM_AVAILABLE
      mem = GetProcessMem.new
      return mem.mb
    end

    # Fallback to manual methods
    if RUBY_PLATFORM =~ /linux/
      # Linux: read from /proc
      status_file = "/proc/#{Process.pid}/status"
      if File.exist?(status_file)
        status = File.read(status_file)
        if status =~ /VmRSS:\s+(\d+)\s+kB/
          return $1.to_i / 1024.0 # Convert KB to MB
        end
      end
    elsif RUBY_PLATFORM =~ /darwin/
      # macOS: use ps command
      output = `ps -o rss= -p #{Process.pid}`.strip
      return output.to_i / 1024.0 # Convert KB to MB
    end

    # Fallback: return nil if we can't measure
    nil
  end

  # Test execution time for single validation
  def test_single_validation_speed
    puts "\n=== Single Validation Speed Test ==="

    times = []

    # Run 5 times to get average
    5.times do |i|
      time = Benchmark.realtime do
        @validator.validate(MEDIUM_CSS)
      end
      times << time
      puts "  Run #{i+1}: #{format('%.3f', time)} seconds"
    end

    average = times.sum / times.size
    puts "  Average: #{format('%.3f', average)} seconds"
    puts "  Min: #{format('%.3f', times.min)} seconds"
    puts "  Max: #{format('%.3f', times.max)} seconds"

    # Warn if average time is too high
    if average > 2.0
      puts "  ⚠️  WARNING: Average validation time is high (#{format('%.3f', average)}s)"
    end

    assert times.all? { |t| t < 10.0 }, "Validation should complete within 10 seconds"
  end

  # Test memory usage during validation
  def test_memory_usage_during_validation
    skip "Memory measurement not available on this platform" unless get_memory_usage

    puts "\n=== Memory Usage During Validation ==="

    GC.start # Clean up before measuring
    sleep 0.1

    initial_memory = get_memory_usage
    puts "  Initial memory: #{format('%.2f', initial_memory)} MB"

    # Perform validation
    result = @validator.validate(LARGE_CSS)

    peak_memory = get_memory_usage
    puts "  Peak memory: #{format('%.2f', peak_memory)} MB"

    memory_used = peak_memory - initial_memory
    puts "  Memory used: #{format('%.2f', memory_used)} MB"

    # Warn if memory usage is high
    if memory_used > 200
      puts "  ⚠️  WARNING: High memory usage detected (#{format('%.2f', memory_used)} MB)"
    end

    assert result.is_a?(Ruby::CSS::Validator::ValidationResult)
  end

  # Test memory accumulation over multiple sequential validations
  def test_sequential_validations_memory
    skip "Memory measurement not available on this platform" unless get_memory_usage

    puts "\n=== Sequential Validations Memory Test ==="

    GC.start
    sleep 0.1

    initial_memory = get_memory_usage
    puts "  Initial memory: #{format('%.2f', initial_memory)} MB"

    memory_readings = []

    10.times do |i|
      @validator.validate(MEDIUM_CSS)

      if (i + 1) % 2 == 0
        GC.start
        sleep 0.1
        current_memory = get_memory_usage
        memory_readings << current_memory
        puts "  After #{i+1} validations: #{format('%.2f', current_memory)} MB"
      end
    end

    final_memory = memory_readings.last
    memory_growth = final_memory - initial_memory

    puts "  Final memory: #{format('%.2f', final_memory)} MB"
    puts "  Total growth: #{format('%.2f', memory_growth)} MB"

    # Check if memory is growing linearly (memory leak indicator)
    if memory_readings.size >= 3
      # Calculate if there's a concerning upward trend
      first_half_avg = memory_readings[0...(memory_readings.size/2)].sum / (memory_readings.size/2)
      second_half_avg = memory_readings[(memory_readings.size/2)..-1].sum / (memory_readings.size - memory_readings.size/2)
      growth_rate = second_half_avg - first_half_avg

      if growth_rate > 50
        puts "  ⚠️  WARNING: Significant memory growth detected (#{format('%.2f', growth_rate)} MB)"
        puts "  This may indicate a memory leak or high JVM startup overhead"
      end
    end

    # Memory should not grow unreasonably (allowing for some JVM overhead)
    assert memory_growth < 500, "Memory growth should be reasonable for sequential validations"
  end

  # Test validation speed with different CSS sizes
  def test_validation_speed_by_size
    puts "\n=== Validation Speed by CSS Size ==="

    test_cases = [
      { name: "Small CSS (1 rule)", css: SMALL_CSS },
      { name: "Medium CSS (7 rules)", css: MEDIUM_CSS },
      { name: "Large CSS (100 rules)", css: LARGE_CSS }
    ]

    test_cases.each do |test_case|
      time = Benchmark.realtime do
        @validator.validate(test_case[:css])
      end

      puts "  #{test_case[:name]}: #{format('%.3f', time)} seconds"
    end
  end

  # Test JVM startup overhead by comparing first vs subsequent runs
  def test_jvm_startup_overhead
    puts "\n=== JVM Startup Overhead Test ==="

    # Create a new validator to ensure clean state
    validator = RubyCssValidator.new

    first_run_time = Benchmark.realtime do
      validator.validate(SMALL_CSS)
    end

    # Run several more times
    subsequent_times = []
    5.times do
      time = Benchmark.realtime do
        validator.validate(SMALL_CSS)
      end
      subsequent_times << time
    end

    avg_subsequent = subsequent_times.sum / subsequent_times.size

    puts "  First run: #{format('%.3f', first_run_time)} seconds"
    puts "  Subsequent avg: #{format('%.3f', avg_subsequent)} seconds"
    puts "  Startup overhead: #{format('%.3f', first_run_time - avg_subsequent)} seconds"

    # Each run spawns a new Java process, so times should be similar
    # If there's a large difference, it indicates OS-level caching
    overhead_percentage = ((first_run_time - avg_subsequent) / avg_subsequent * 100).abs
    puts "  Overhead percentage: #{format('%.1f', overhead_percentage)}%"
  end

  # Detailed memory profiling using benchmark-memory gem
  def test_detailed_memory_profiling
    skip "benchmark-memory gem not available" unless BENCHMARK_MEMORY_AVAILABLE

    puts "\n=== Detailed Memory Profiling (using benchmark-memory) ==="

    report = Benchmark.memory do |x|
      x.report("Small CSS") { @validator.validate(SMALL_CSS) }
      x.report("Medium CSS") { @validator.validate(MEDIUM_CSS) }
      x.report("Large CSS") { @validator.validate(LARGE_CSS) }
      x.compare!
    end

    puts report
  end

  # Test memory usage with get_process_mem gem
  def test_accurate_memory_measurement
    skip "get_process_mem gem not available" unless GET_PROCESS_MEM_AVAILABLE

    puts "\n=== Accurate Memory Measurement (using get_process_mem) ==="

    mem = GetProcessMem.new
    puts "  Initial memory: #{mem.mb} MB"

    # Measure memory before validation
    GC.start
    sleep 0.1
    before = GetProcessMem.new

    # Run validation
    @validator.validate(LARGE_CSS)

    # Measure memory after validation
    after = GetProcessMem.new

    puts "  Before validation: #{before.mb} MB"
    puts "  After validation: #{after.mb} MB"
    puts "  Memory increase: #{after.mb - before.mb} MB"

    # Test with multiple validations
    puts "\n  Running 10 sequential validations..."
    start = GetProcessMem.new

    10.times do |i|
      @validator.validate(MEDIUM_CSS)
    end

    finish = GetProcessMem.new
    puts "  Memory before: #{start.mb} MB"
    puts "  Memory after: #{finish.mb} MB"
    puts "  Total increase: #{finish.mb - start.mb} MB"
    puts "  Average per validation: #{(finish.mb - start.mb) / 10.0} MB"
  end

  # Benchmark report generator
  def test_generate_performance_report
    skip "Skipping report generation in normal test runs" unless ENV['GENERATE_REPORT']

    puts "\n=== Generating Performance Report ==="

    report = {
      timestamp: Time.now.iso8601,
      ruby_version: RUBY_VERSION,
      platform: RUBY_PLATFORM,
      results: {}
    }

    # Speed test
    times = 5.times.map do
      Benchmark.realtime { @validator.validate(MEDIUM_CSS) }
    end

    report[:results][:speed] = {
      average_seconds: times.sum / times.size,
      min_seconds: times.min,
      max_seconds: times.max
    }

    # Memory test (if available)
    if get_memory_usage
      GC.start
      initial_mem = get_memory_usage
      @validator.validate(LARGE_CSS)
      final_mem = get_memory_usage

      report[:results][:memory] = {
        initial_mb: initial_mem,
        final_mb: final_mem,
        used_mb: final_mem - initial_mem
      }
    end

    # Save report
    report_file = 'performance_report.json'
    File.write(report_file, JSON.pretty_generate(report))
    puts "  Report saved to: #{report_file}"

    puts "\n" + JSON.pretty_generate(report)
  end
end
