require "acts_as_metadata/version"
require 'acts_as_metadata/models/meta_data'
require 'acts_as_metadata/active_record/acts/meta_data'

# ActiveRecord::Base.class_eval { include ActiveRecord::Acts::MetaData }

ActiveRecord::Base.send(:include, ActiveRecord::Acts::MetaData)