module ActiveRecord
  module Acts #:nodoc:
    module MetaData #:nodoc:
      
      def self.included(base)
        base.extend(ClassMethods)
        self.class_eval do
        end
      end
      
      module ClassMethods
        
        # :meta => [ :this => {},  ]
        # todo:  default value
        def acts_as_metadata(options = {} )
          @_meta_attributes = options[ :meta ]
          
          include ActiveRecord::Acts::MetaData::InstanceMethods
          initialize_meta_attributes
          
          # have to execute here so that the scope is of the current Class
          alias_method_chain :save, :metadata
          alias_method_chain :save!, :metadata
          
          @is_meta_dirty = false
        end
        

        def initialize_meta_attributes
          return if( @_meta_attributes.nil? or @_meta_attributes.length == 0 )
          define_macro_attribute_accessor()
          
          # have to define the instance variable this way
          # so that we can access to the list of the meta attributes
          s = @_meta_attributes.to_a
          define_method "__meta_attributes__" do
            s
          end
        end #def


        # define all the attribute accessors 
        def define_macro_attribute_accessor
          @_meta_attributes.each do |meta|
            define_attribute_accessor( meta )
          end # each
        end #def
      
        # define the necessar accessors and the ActiveRecord-specific *_before_type_cast for the meta attribute
        def define_attribute_accessor( meta )
            # read
            define_method meta do
              load_meta if @meta_attributes.nil?
              if @meta_attributes[ meta ].nil?
                nil
              else
                @meta_attributes[ meta ][ "value" ]
              end
            end
            
            # for boolean flag
            define_method "#{meta}?" do
              load_meta if @meta_attributes.nil?
              if @meta_attributes[ meta ].nil?
                false
              else
                @meta_attributes[ meta ][ "value" ].to_s == "true" || @meta_attributes[ meta ][ "value" ] == "1" || @meta_attributes[ meta ][ "value" ].to_s == "t"
              end
            end
            
            # {fake column}_before_type_cast for ActiveRecord
            define_method "#{meta}_before_type_cast" do
              load_meta if @meta_attributes.nil?
              @meta_attributes[ meta ].nil? ? nil : @meta_attributes[ meta ][ "value" ]
            end
            
            # write
            define_method "#{meta}=" do |value|
              load_meta if @meta_attributes.nil?
              if @meta_attributes[ meta ].nil? 
                @meta_attributes[ meta ] = { "id" => nil, "key" => meta, "model" => self.class.to_s, "model_id" => self.id, "value" => value }
              else
                @meta_attributes[ meta ][ "value" ] = value
              end
              
              # puts @meta_attributes.inspect
              
              @meta_attributes_is_dirty[ meta ] = @is_meta_dirty = true
              
            end
        end
        
      end
      
      module InstanceMethods

        # load all the attributes associated with this particular model
        def load_meta

          @meta_attributes = Hash.new()
          @meta_attributes_is_dirty = Hash.new()
          # assign the internally used instance variable @_meta_attributes
          # __meta_attributes__ contains the list of the original, default meta attributes,
          # we use this list to construct the add/ delete statements
          @_meta_attributes = __meta_attributes__().nil? ? Array.new : __meta_attributes__
          
          # skip loading if the current record is new.  We don't need to load anything
          return if self.new_record?
          
          # puts @model_meta_table
          
          db = self.class.connection
          values = ActiveRecord::Base.connection().select_all(
            "SELECT * FROM model_metas WHERE #{db.quote_column_name( 'model_id' )} = '#{id}' AND #{db.quote_column_name( 'model' )} = '#{self.class}'")
          
          # parse the key and populate the hash
          # TODO: implement multiple value for meta
          # @meta_attributes = {}
          
          values.each do |value| 
            @meta_attributes[ value[ 'key'] ] = value
            @meta_attributes_is_dirty[ value['key'] ] = false
          end
          
          # reset the dirty flag
          @is_meta_dirty = false
        end
        
        attr_reader :is_meta_dirty
        attr_accessor :_meta_attributes
        
        # Wrapper for the save method (most likely the save_with_validation)
        def save_with_metadata(perform_validation = true)
          if perform_validation && valid? || !perform_validation
            save_without_metadata
            
            # skip if meta has not been changed 
            return true unless @is_meta_dirty
            
            # Save the metadata
            # check for nil
            meta_to_delete = Array.new
            meta_to_update = Array.new
            meta_to_insert = Array.new
            
            @meta_attributes.keys.each do |meta|
              next unless @meta_attributes_is_dirty[ meta ]
              
              # delete un-existing meta, or meta that has been deleted ( value and id is set to nil )
              if  @meta_attributes[ meta ].nil? or ( @meta_attributes[ meta ][ "value" ].nil? and !@meta_attributes[ meta ][ "id" ].nil? )
                # delete the attributes 
                meta_to_delete << meta
              else
                if @meta_attributes[ meta ][ "id" ].nil?
                  meta_to_insert << meta
                else
                  meta_to_update << meta
                end
              end
            end
            
            db = self.class.connection
            
            if meta_to_delete.length > 0
              sql = "DELETE FROM model_metas WHERE #{db.quote_column_name('model_id')} = #{id} AND #{db.quote_column_name('model')} = '#{self.class}' AND ( " + meta_to_delete.collect{ |meta| " #{db.quote_column_name('key')} = '#{meta}' " }.join(" OR ") + ")"
              db.delete( sql )
              
              # remove the entry from the internal meta hash
              meta_to_delete.each do |meta| 
                @meta_attributes.delete( meta ) 
                @_meta_attributes.delete( meta )
              end
              
            end

            
            meta_to_insert.each do |meta| 
              value_with_quotes = db.quote( @meta_attributes[ meta ][ "value" ] ) 
              sql = sprintf( "INSERT INTO model_metas ( #{db.quote_column_name('key')} , #{db.quote_column_name('model')}, #{db.quote_column_name('model_id')}, #{db.quote_column_name('value')} ) VALUES ( '#{meta}', '#{self.class}', '#{self.id}', #{value_with_quotes} )" ) 
              new_id = db.insert( sql )
              @meta_attributes[ meta ][ "id" ] = new_id
            end
            
            
            meta_to_update.each do |meta|
              value_with_quotes = db.quote( @meta_attributes[ meta ][ "value" ] )
              sql = "UPDATE model_metas SET #{db.quote_column_name('value')} =  #{value_with_quotes} WHERE #{db.quote_column_name('key')} = '#{meta}' AND #{db.quote_column_name('model')} = '#{self.class}' AND #{db.quote_column_name('model_id')} = '#{self.id}' "
              db.update( sql )
            end
            
            _mark_metadata_not_dirty()
            
            return true
            
          else
            return false
          end
        end

    
        # Attempts to save the record just like Base#save but will raise a 
        # RecordInvalid exception instead of returning false
        # if the record is not valid.
        def save_with_metadata!
          if valid?
            save_without_metadata!
            save_with_metadata
          else
            raise RecordInvalid.new(self)
          end
        end
        
        private
        def _mark_metadata_not_dirty
          @is_meta_dirty = false
          @meta_attributes_is_dirty.keys.each { |meta| @meta_attributes_is_dirty[ meta ] = false }
        end
        
      end #module InstanceMethods
    end
    
  end
end


# ActiveRecord::Base.send(:include, ActiveRecord::Acts::MetaData)