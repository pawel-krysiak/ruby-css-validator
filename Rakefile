require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/test_*.rb'].exclude('test/test_performance.rb', 'test/test_active_record.rb')
  t.verbose = true
end

Rake::TestTask.new(:test_active_record) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/test_active_record.rb']
  t.verbose = true
end

Rake::TestTask.new(:test_performance) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/test_performance.rb']
  t.verbose = true
end

desc "Run all tests including performance and ActiveRecord tests"
task :test_all do
  Rake::Task['test'].invoke
  Rake::Task['test_active_record'].invoke
  Rake::Task['test_performance'].invoke
end

desc "Generate performance report"
task :performance_report do
  ENV['GENERATE_REPORT'] = '1'
  Rake::Task['test_performance'].invoke
end

task default: :test
