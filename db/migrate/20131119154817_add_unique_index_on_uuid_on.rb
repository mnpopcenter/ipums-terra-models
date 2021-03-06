# Copyright (c) 2012-2017 Regents of the University of Minnesota
#
# This file is part of the Minnesota Population Center's IPUMS Terra Project.
# For copyright and licensing information, see the NOTICE and LICENSE files
# in this project's top-level directory, and also on-line at:
#   https://github.com/mnpopcenter/ipums-terra-models

class AddUniqueIndexOnUuidOn < ActiveRecord::Migration

  def up
    remove_index :extract_requests, :uuid
    add_index :extract_requests, :uuid, :unique => true #, :name => :unique_extract_requests_uuid_index
  end

  def down
  end
end
