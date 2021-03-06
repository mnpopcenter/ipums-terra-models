# Copyright (c) 2012-2017 Regents of the University of Minnesota
#
# This file is part of the Minnesota Population Center's IPUMS Terra Project.
# For copyright and licensing information, see the NOTICE and LICENSE files
# in this project's top-level directory, and also on-line at:
#   https://github.com/mnpopcenter/ipums-terra-models

class GeogInstanceGeogCodeWider < ActiveRecord::Migration

  def change
    change_column :geog_instances, :geog_code, :string, limit: 64
    change_column :geog_instances, :str_code,  :string, limit: 64
  end
end
