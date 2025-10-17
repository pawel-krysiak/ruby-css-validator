require_relative 'test_helper'
require 'benchmark'

# Performance test suite for CSS Validator
class TestPerformance < Minitest::Test
  SMALL_CSS = "body { color: red; }"

  MEDIUM_CSS = <<~CSS
    body { margin: 0; padding: 0; font-family: Arial, sans-serif; }
    .container { max-width: 1200px; margin: 0 auto; }
    .header { background: #333; color: white; padding: 20px; }
    .content { padding: 40px 20px; }
    .footer { background: #f5f5f5; padding: 20px; text-align: center; }
  CSS

  LARGE_CSS = (1..100).map { |i|
    ".class-#{i} { color: ##{i.to_s.rjust(6, '0')}; margin: #{i}px; padding: #{i}px; }"
  }.join("\n")

  def setup
    @validator = RubyCssValidator.new
    @validator.validate(SMALL_CSS) rescue nil # Warmup
    sleep 0.5 # Let warmup JVM die completely
  end

  def get_ruby_memory
    case RUBY_PLATFORM
    when /linux/
      File.read("/proc/#{Process.pid}/status")[/VmRSS:\s+(\d+)/, 1].to_i / 1024.0 rescue nil
    when /darwin/
      `ps -o rss= -p #{Process.pid}`.to_i / 1024.0 rescue nil
    end
  end

  def get_java_memory
    java_pids = `pgrep -f "java.*css-validator"`.split.map(&:strip)
    return { count: 0, total_mb: 0 } if java_pids.empty?

    total_mb = java_pids.sum do |pid|
      case RUBY_PLATFORM
      when /linux/
        File.read("/proc/#{pid}/status")[/VmRSS:\s+(\d+)/, 1].to_i / 1024.0 rescue 0
      when /darwin/
        `ps -o rss= -p #{pid}`.to_i / 1024.0 rescue 0
      end
    end

    { count: java_pids.size, total_mb: total_mb }
  end

  def get_total_memory
    ruby_mb = get_ruby_memory
    java = get_java_memory
    return nil unless ruby_mb

    { ruby_mb: ruby_mb, java_count: java[:count], java_mb: java[:total_mb], total_mb: ruby_mb + java[:total_mb] }
  end

  def monitor_memory
    samples, monitoring = [], true
    Thread.new { samples << get_total_memory while monitoring; sleep 0.05 }
    yield
    monitoring = false
    sleep 0.1
    samples.compact
  end

  def test_validation_speed
    puts "\n=== Validation Speed ==="
    [SMALL_CSS, MEDIUM_CSS, LARGE_CSS].each_with_index do |css, i|
      avg = 3.times.map { Benchmark.realtime { @validator.validate(css) } }.sum / 3.0
      puts "  #{['Small', 'Medium', 'Large'][i]}: #{'%.3f' % avg}s"
    end
    assert true
  end

  def test_parallel_validations
    puts "\n=== Parallel Validations (10 Threads) ==="
    samples = monitor_memory do
      10.times.map { Thread.new { @validator.validate(MEDIUM_CSS) } }.each(&:join)
    end

    peak = samples.max_by { |s| s[:total_mb] }
    puts "  Peak: #{'%.0f' % peak[:total_mb]} MB (Ruby: #{'%.0f' % peak[:ruby_mb]} + Java: #{'%.0f' % peak[:java_mb]} MB, #{peak[:java_count]} JVMs)"
    assert true
  end

  def test_jvm_memory_per_thread
    skip unless get_java_memory
    puts "\n=== Memory Per Thread ==="

    [1, 2, 5, 10].each do |n|
      sleep 2  # Let JVMs die
      samples = monitor_memory { n.times.map { Thread.new { @validator.validate(MEDIUM_CSS) } }.each(&:join) }
      peak = samples.max_by { |s| s[:total_mb] }
      puts "  #{n} thread(s): #{'%.0f' % peak[:total_mb]} MB (#{'%.0f' % (peak[:total_mb] / n)} MB/thread)"
    end

    assert true
  end
end
