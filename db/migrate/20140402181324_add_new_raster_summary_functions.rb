# Copyright (c) 2012-2017 Regents of the University of Minnesota
#
# This file is part of the Minnesota Population Center's IPUMS Terra Project.
# For copyright and licensing information, see the NOTICE and LICENSE files
# in this project's top-level directory, and also on-line at:
#   https://github.com/mnpopcenter/ipums-terra-models

class AddNewRasterSummaryFunctions < ActiveRecord::Migration

  # Note that the PostgreSQL JDBC driver has problems creating stored proces that involve the DECLARE keyword.
  def self.up
    # this version of the stored proc isn't usable because it creates a local variable via the DECLARE keyword, which breaks the PostgreSQL 9.1.4 JDBC driver.
    summary_calc_sql =<<-END_OF_PROC
CREATE OR REPLACE FUNCTION terrapop_raster_summary_calc_v2(raster_op_name varchar(32), rast raster)
  RETURNS numeric(20,4) as $$
DECLARE
  summary_val numeric(20,4);
BEGIN
  CASE raster_op_name
    WHEN 'max' THEN summary_val := CAST((ST_SummaryStats(rast)).max as numeric(20,4));
    WHEN 'min' THEN summary_val := CAST((ST_SummaryStats(rast)).min as numeric(20,4));
    WHEN 'mean' THEN summary_val := CAST((ST_SummaryStats(rast)).mean as numeric(20,4));
    WHEN 'count' THEN summary_val := CAST((ST_SummaryStats(rast)).count as numeric(20,4));
    WHEN 'sum' THEN summary_val := CAST((ST_SummaryStats(rast)).sum as numeric(20,4));
    WHEN 'mode' THEN SELECT histogram.value into summary_val
                      FROM (SELECT (ST_ValueCount(rast,1)).*) As histogram
                      ORDER BY histogram.count desc limit 1;
    ELSE summary_val := null;
  END CASE;

  RETURN summary_val;
END;
$$ LANGUAGE plpgsql
END_OF_PROC

    # so, since declare is off-limits, we can use a different structure which requires having a utility function.
    # This function is also somewhat awkward, the RETURN at the end returns the value in the single OUT parameter
    # as declared in the RETURNS part of the signature.

    # Note that we can't use SELECT INTO STRICT here because the return value might be NULL, if the whole raster tile is nodata.

    summary_calc_modal_sql = <<-END_OF_PROC
CREATE OR REPLACE FUNCTION terrapop_modal_value_v2(rast raster, OUT modal numeric) RETURNS numeric
  LANGUAGE plpgsql
  AS $$
BEGIN
  SELECT histogram.value into modal
    FROM (SELECT (ST_ValueCount(rast,1)).*) As histogram
    ORDER BY histogram.count desc limit 1;
  return;
END;
$$;
END_OF_PROC

    summary_calc_num_classes_sql = <<-END_OF_PROC
CREATE OR REPLACE FUNCTION terrapop_num_classes_v2(rast raster, OUT num_classes numeric) RETURNS numeric
  LANGUAGE plpgsql
  AS $$
BEGIN
  SELECT count(histogram.*) into num_classes
    FROM (SELECT (ST_ValueCount(rast,1)).*) As histogram;
  return;
END;
$$;
END_OF_PROC


    summary_calc_nodeclare_sql =<<-END_OF_PROC
CREATE OR REPLACE FUNCTION terrapop_raster_summary_calc_v2(raster_op_name varchar(32), rast raster, area double precision) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN CASE raster_op_name
    WHEN 'max' THEN CAST((ST_SummaryStats(rast)).max as double precision)
    WHEN 'min' THEN CAST((ST_SummaryStats(rast)).min as double precision)
    WHEN 'mean' THEN CAST((ST_SummaryStats(rast)).mean as double precision)
    WHEN 'count' THEN CAST((ST_SummaryStats(rast)).count as double precision)
    WHEN 'sum' THEN CAST((ST_SummaryStats(rast)).sum as double precision)
    WHEN 'mode' THEN terrapop_modal_value_v2(rast)
    WHEN 'num_classes' THEN terrapop_num_classes_v2(rast)
    WHEN 'total_area_bin' THEN CAST((ST_SummaryStats(rast)).sum as double precision)
    WHEN 'percent_area_bin' THEN CAST(((ST_SummaryStats(rast)).sum  / area ) as double precision)
    WHEN 'total_area_areal' THEN CAST((ST_SummaryStats(rast)).sum as double precision)
    WHEN 'percent_area_areal' THEN CAST(((ST_SummaryStats(rast)).sum  / area ) as double precision)
    ELSE null
  END;
END;
$$;
END_OF_PROC

    summary_sql = <<-END_OF_PROC
    CREATE OR REPLACE FUNCTION terrapop_raster_summary_v3(sample_geog_lvl_id bigint, raster_var_id bigint, raster_var_ref_id bigint, raster_op_name varchar(32))
    RETURNS TABLE(sample_geog_level_id bigint, raster_variable_id bigint, raster_operation_name varchar(32), geog_instance_id bigint,
      geog_instance_label varchar(255), geog_instance_code numeric(20,0), raster_mnemonic varchar(255),
      boundary_area double precision, raster_area double precision, summary_value double precision) AS $$
    BEGIN
        RETURN QUERY
        
           SELECT final.sample_geog_level_id, final.raster_variable_id, final.raster_op_name, final.geog_instance_id,
                  final.geog_instance_label, final.geog_instance_code, final.mnemonic, final.boundary_area, final.raster_area, final.value FROM (
              select unioned_rast.sample_geog_level_id, unioned_rast.raster_variable_id, raster_op_name,
                     unioned_rast.geog_instance_id, unioned_rast.geog_instance_label, unioned_rast.geog_instance_code,
                     CAST(unioned_rast.raster_variable_name || '_' || raster_op_name as varchar(255)) as mnemonic,
                     unioned_rast.boundary_area,
                     unioned_rast.raster_area,
                     terrapop_raster_summary_calc_v2(raster_op_name, St_Union(unioned_rast.rast), unioned_rast.raster_area)::double precision as value
              from (
                select base.sample_geog_level_id, base.raster_variable_id, base.geog_instance_id, base.geog_instance_label,
                      base.geog_instance_code, base.raster_variable_name,
                      base.boundary_area::double precision AS boundary_area,
                      /*ST_Union(ST_MapAlgebra(base.rast, ref_base.rast, '([rast1] * [rast2])::float')) as rast,*/
                      /*ST_GeoReference(ST_Union(base.rast), 'GDAL') AS base_esri_ref,*/
                      ST_Union(ST_MapAlgebra(base.rast, ST_SetGeoReference(ref_base.rast, ST_GeoReference(base.rast, 'GDAL') , 'GDAL'), '([rast1] * [rast2])::float')) as rast ,
                      terrapop_raster_area_v1(base.geog_instance_id, raster_var_ref_id)::double precision AS raster_area
                from (
                  SELECT sgl.id as "sample_geog_level_id", my_raster.raster_variable_id as "raster_variable_id",
                    gi.id as "geog_instance_id", gi.label as "geog_instance_label", gi.code as "geog_instance_code",
                    my_raster.name as "raster_variable_name", ST_AREA(bound.geog) as boundary_area,
                    ST_Union(ST_Clip(my_raster.rast, bound.geog::geometry)) as rast
                  FROM sample_geog_levels sgl
                  inner join geog_instances gi on sgl.id = gi.sample_geog_level_id
                  inner join boundaries bound on bound.geog_instance_id = gi.id
                  inner join rasters my_raster on ST_Intersects(my_raster.rast, bound.geog::geometry)
                  where sgl.id = sample_geog_lvl_id and my_raster.raster_variable_id = raster_var_id
                  group by sgl.id, my_raster.raster_variable_id, gi.id, gi.label, gi.code, my_raster.name, boundary_area
                ) base,
                ( SELECT ST_Union(ST_Clip(my_raster.rast, bound.geog::geometry)) as rast
                          FROM sample_geog_levels sgl
                          inner join geog_instances gi on sgl.id = gi.sample_geog_level_id
                          inner join boundaries bound on bound.geog_instance_id = gi.id
                          inner join rasters my_raster on ST_Intersects(my_raster.rast, bound.geog::geometry)
                          where sgl.id = sample_geog_lvl_id and my_raster.raster_variable_id = raster_var_ref_id
                ) ref_base
                group by base.sample_geog_level_id, base.raster_variable_id, base.geog_instance_label,
                    base.geog_instance_id, base.geog_instance_code, base.raster_variable_name,
                    base.boundary_area
              ) unioned_rast
              group by
                unioned_rast.sample_geog_level_id, unioned_rast.raster_variable_id,
                raster_op_name, unioned_rast.geog_instance_id, unioned_rast.geog_instance_label,
                unioned_rast.geog_instance_code, mnemonic, unioned_rast.boundary_area, unioned_rast.raster_area
              order by unioned_rast.geog_instance_code
            ) final
            group by final.sample_geog_level_id,
              final.raster_variable_id,
              final.raster_op_name,
              final.geog_instance_id,
              final.geog_instance_label,
              final.geog_instance_code,
              final.mnemonic,
              final.boundary_area,
              final.raster_area,
              final.value
            order by final.geog_instance_code;

    END;
    $$ LANGUAGE plpgsql
END_OF_PROC
          

    area_sql = <<-END_OF_PROC
    CREATE OR REPLACE FUNCTION terrapop_raster_area_v1(_geog_instance_id bigint, raster_var_ref_id bigint)
    RETURNS TABLE(raster_area double precision) AS $$
    BEGIN
        RETURN QUERY
        SELECT final.raster_area FROM (
            select unioned_rast.raster_area AS raster_area
            from (
              select SUM((ST_SummaryStats((base.rast))).sum::double precision) AS raster_area
              from (
                SELECT ST_Union(ST_Clip(my_raster.rast, bound.geog::geometry)) as rast
                FROM geog_instances gi, boundaries bound
                inner join rasters my_raster on ST_Intersects(my_raster.rast, bound.geog::geometry)
                where gi.id = _geog_instance_id and my_raster.raster_variable_id = raster_var_ref_id AND bound.geog_instance_id = gi.id
                group by my_raster.raster_variable_id, gi.id, gi.label, gi.code, my_raster.name
              ) base
            ) unioned_rast
          ) final
          group by final.raster_area;
    END;
    $$ LANGUAGE plpgsql
END_OF_PROC

    execute summary_calc_modal_sql
    execute summary_calc_num_classes_sql
    execute summary_calc_nodeclare_sql
    execute area_sql
    execute summary_sql
  end

  def self.down
    execute 'drop function if exists terrapop_modal_value_v2(rast raster, OUT modal numeric)'
    execute 'drop function if exists terrapop_num_classes_v2(rast raster, OUT num_classes numeric)'
    execute 'drop function if exists terrapop_raster_summary_calc_v2(raster_op_name varchar(32), rast raster, area float)'
    execure 'drop function if exists terrapop_raster_area_v1(sample_geog_lvl_id bigint, raster_var_ref_id bigint)'
    execute 'drop function if exists terrapop_raster_summary_v3(sample_geog_lvl_id bigint, raster_var_id bigint, raster_var_ref_id bigint, raster_op_name varchar(32))'
    
  end
end
