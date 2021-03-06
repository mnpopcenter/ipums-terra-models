# Copyright (c) 2012-2017 Regents of the University of Minnesota
#
# This file is part of the Minnesota Population Center's IPUMS Terra Project.
# For copyright and licensing information, see the NOTICE and LICENSE files
# in this project's top-level directory, and also on-line at:
#   https://github.com/mnpopcenter/ipums-terra-models

class AddOtherRasterVariablesToRasterVariableClassification < ActiveRecord::Migration

  def change
    add_column :raster_variable_classifications, :mosaic_raster_variable_id, :bigint
    
    add_index :raster_variable_classifications, :mosaic_raster_variable_id, name: :rvc_mosaic_raster_variable_id
    foreign_key_raw :raster_variable_classifications, :mosaic_raster_variable_id, :raster_variables, :id
    
  end
end
