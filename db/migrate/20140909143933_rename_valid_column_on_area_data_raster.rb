# Copyright (c) 2012-2017 Regents of the University of Minnesota
#
# This file is part of the Minnesota Population Center's IPUMS Terra Project.
# For copyright and licensing information, see the NOTICE and LICENSE files
# in this project's top-level directory, and also on-line at:
#   https://github.com/mnpopcenter/ipums-terra-models

class RenameValidColumnOnAreaDataRaster < ActiveRecord::Migration

  def change
    rename_column :area_data_rasters, :valid, :is_valid
  end
end
