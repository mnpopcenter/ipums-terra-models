# Copyright (c) 2012-2017 Regents of the University of Minnesota
#
# This file is part of the Minnesota Population Center's IPUMS Terra Project.
# For copyright and licensing information, see the NOTICE and LICENSE files
# in this project's top-level directory, and also on-line at:
#   https://github.com/mnpopcenter/ipums-terra-models

class UpdateNewRasters < ActiveRecord::Migration

  def up
    sql=<<SQL
    DROP VIEW new_rasters;
SQL
    execute(sql)
    sql=<<SQL
CREATE OR REPLACE VIEW new_rasters AS
  WITH loaded_rasters as
  (
  SELECT r_table_schema as schema, r_table_name as tablename
  FROM raster_columns
  WHERE r_table_schema != 'gis_rasters'
  ), raster_metadata as
  (
  SELECT rv.id, rv.mnemonic, rtn.schema, rtn.tablename, rb.band_num
  FROM raster_table_names rtn
  inner join raster_bands rb on rtn.id = rb.raster_table_name_id
  inner join raster_variable_raster_bands rvrb on rb.id = rvrb.raster_band_id
  inner join raster_variables rv on rvrb.raster_variable_id = rv.id
  ), all_data as
  (
  SELECT rm.id,rm.mnemonic, rm.schema, rm.tablename, rm.band_num, lr.schema as loaded_schema, lr.tablename as loaded_table,
  rv.area_reference_id, rv.second_area_reference_id
  FROM raster_metadata rm
  left join loaded_rasters lr on (rm.schema = lr.schema and rm.tablename = lr.tablename)
  left join raster_variables rv on (rm.id = rv.id)
  )
  SELECT id, mnemonic, schema, tablename, band_num, area_reference_id, second_area_reference_id,
    CASE WHEN loaded_table != ''
    THEN 1
    END::boolean as data_exists
  FROM all_data ;
SQL
    execute(sql)
  end

  def down
    sql=<<SQL
    DROP VIEW new_rasters;
SQL
    execute(sql)
    sql=<<SQL
CREATE OR REPLACE VIEW new_rasters AS
 WITH loaded_rasters AS (
         SELECT raster_columns.r_table_schema AS schema,
            raster_columns.r_table_name AS tablename
           FROM raster_columns
          WHERE raster_columns.r_table_schema <> 'gis_rasters'::name
        ), raster_metadata AS (
         SELECT rv.id,
            rv.mnemonic,
            rtn.schema,
            rtn.tablename,
            rb.band_num
           FROM raster_table_names rtn
             JOIN raster_bands rb ON rtn.id = rb.raster_table_name_id
             JOIN raster_variable_raster_bands rvrb ON rb.id = rvrb.raster_band_id
             JOIN raster_variables rv ON rvrb.raster_variable_id = rv.id
        ), all_data AS (
         SELECT rm.id,
            rm.mnemonic,
            rm.schema,
            rm.tablename,
            rm.band_num,
            lr.schema AS loaded_schema,
            lr.tablename AS loaded_table
           FROM raster_metadata rm
             LEFT JOIN loaded_rasters lr ON rm.schema::name = lr.schema AND rm.tablename::name = lr.tablename
        )
 SELECT all_data.id,
    all_data.mnemonic,
    all_data.schema,
    all_data.tablename,
    all_data.band_num,
        CASE
            WHEN all_data.loaded_table <> ''::name THEN 1
            ELSE NULL::integer
        END::boolean AS data_exists
   FROM all_data;
SQL
     execute(sql)
  end

end
