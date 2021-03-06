# Copyright (c) 2012-2017 Regents of the University of Minnesota
#
# This file is part of the Minnesota Population Center's IPUMS Terra Project.
# For copyright and licensing information, see the NOTICE and LICENSE files
# in this project's top-level directory, and also on-line at:
#   https://github.com/mnpopcenter/ipums-terra-models

require 'nhgis_database'

module Nhgis
  class TimeSeriesTableDataset < NhgisActiveRecord::Base
    self.table_name = "time_series_tables_x_datasets"

    belongs_to :time_series_table
    belongs_to :dataset
  end
end