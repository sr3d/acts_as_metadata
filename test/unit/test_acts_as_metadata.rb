require File.dirname(__FILE__) + '/../test_helper'

class ActsAsMetadataTest < Test::Unit::TestCase
  include TestHelper
  
 # Replace this with your real tests.
  def setup
    @story = Story.create( :text => 'Hello world' )
  end
  
  def teardown
    Story.destroy_all
    ModelMeta.destroy_all
  end
  
  def test_initialize_attributes
    assert_nil @story.reading
    assert_nil @story.current_page
  end
  
  def test_attribute_writer
    @story.reading = true
    assert @story.is_meta_dirty
    assert_equal true, @story.reading
  end
  
  def test_attribute_reader
    assert_nil @story.reading
    assert_equal false, @story.reading?
  end
  
  def test_save
    @story.reading = true
    assert @story.is_meta_dirty, 'Meta should be mark dirty'
    
    assert_difference 'ModelMeta.count' do
      # $debug = true
      assert_equal true, @story.save, 'save should return true'
      # $debug = false
    end
    assert_equal false, @story.is_meta_dirty, 'after save, is_meta_dirty should be false'
    story = Story.last
    assert story.reading?, 'reading should be now true'
  end
  
  def test_numeric_value_for_attribute
    @story.current_page = 10
    assert_difference 'ModelMeta.count' do
      assert @story.save, 'save should return true'
    end
    assert_equal 10, @story.current_page
    
    story = Story.last
    assert_equal 10, story.current_page.to_i
  end
  
  def test_remove_attribute
    @story.reading = true
    @story.save
    
    @story.reading = nil
    assert_difference 'ModelMeta.count', -1 do 
      @story.save
    end
    
    assert_equal false, @story.reading?
  end
  
  def test_save_multiple_attributes
    @story.reading = true
    @story.current_page = 10
    
    assert_difference 'ModelMeta.count', 2 do
      @story.save
    end
    
    assert_equal true, @story.reading?
    assert_equal 10, @story.current_page.to_i
  end
  
end