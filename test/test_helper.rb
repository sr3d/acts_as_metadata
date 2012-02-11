require 'rubygems'
require 'bundler/setup'
require "test/unit"
require 'active_record'
require 'logger'
require 'acts_as_metadata' 


module TestHelper
  def assert_difference(expression, difference = 1, &block)
    expression_evaluation = lambda { eval(expression, block.binding) }
    original_value        = expression_evaluation.call
    yield
    assert_equal original_value + difference, expression_evaluation.call
  end
end




ActiveRecord::Base.logger = Logger.new('/tmp/acts_as_metadata.log')
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => '/tmp/acts_as_metadata_test.sqlite')
ActiveRecord::Migration.verbose = false
ActiveRecord::Base.default_timezone = :utc if Time.zone.nil?

ActiveRecord::Schema.define do
  create_table :model_metas, :force => true do |t|
    t.column :key, :string, :null => false
    t.column :model, :string, :null => false
    t.column :model_id, :integer, :null => false
    t.column :value, :string, :null => false
  end

  create_table :stories, :force => true do |table|
    table.string :text
  end
end


# Purely useful for test cases...
class Story < ActiveRecord::Base
  acts_as_metadata :meta => [ 'reading', 'current_page' ]
end
