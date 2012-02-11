require "bundler/gem_tasks"

require 'rake'
require 'rake/testtask'


Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/{functional,unit}/**/test_*.rb'
end
# 
# namespace :test do
#   Rake::TestTask.new(:lint) do |test|
#     test.libs << 'lib' << 'test'
#     test.pattern = 'test/test_active_model_lint.rb'
#   end
#   
#   task :all => ['test']
# end

task :default => 'test'