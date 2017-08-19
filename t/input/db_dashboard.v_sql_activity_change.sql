CREATE VIEW db_dashboard.v_sql_activity_change AS
SELECT DISTINCT coalesce ( c.username, sql.parsing_schema_name ) AS username,
        c.osuser,
        to_char ( cpd.polling_dt, 'YYYY-MM-DD HH24:MI:SS' ) AS curr_polling_dt,
        to_char ( ppd.polling_dt, 'YYYY-MM-DD HH24:MI:SS' ) AS prev_polling_dt,
        CAST ( c.address AS varchar2 ( 50 ) ) AS address_text,
        c.hash_value,
        -- Note that sometimes the previous value of a counter type
        -- parameter is greater than the current value. If that happens
        -- then we assume that there was some form of reset/wraparound
        CASE
            WHEN c.fetches - coalesce ( p.fetches, 0 ) >= 0 THEN c.fetches - coalesce ( p.fetches, 0 )
            ELSE c.fetches -- assume wraparound/reset?
            END AS fetches,
        CASE
            WHEN c.executions - coalesce ( p.executions, 0 ) >= 0 THEN c.executions - coalesce ( p.executions, 0 )
            ELSE c.executions
            END AS executions,
        CASE
            WHEN c.elapsed_time - coalesce ( p.elapsed_time, 0 ) >= 0 THEN
                c.elapsed_time - coalesce ( p.elapsed_time, 0 )
            ELSE c.elapsed_time
            END AS elapsed_time,
        CASE
            WHEN c.rows_processed - coalesce ( p.rows_processed, 0 ) >= 0 THEN
                c.rows_processed - coalesce ( p.rows_processed, 0 )
            ELSE c.rows_processed
            END AS rows_processed,
        c.sharable_mem,
        c.persistent_mem,
        c.runtime_mem,
        CASE
            WHEN c.disk_reads - coalesce ( p.disk_reads, 0 ) >= 0 THEN c.disk_reads - coalesce ( p.disk_reads, 0 )
            ELSE c.disk_reads
            END AS disk_reads,
        CASE
            WHEN c.direct_writes - coalesce ( p.direct_writes, 0 ) >= 0 THEN
                c.direct_writes - coalesce ( p.direct_writes, 0 )
            ELSE c.direct_writes
            END AS direct_writes,
        CASE
            WHEN c.buffer_gets - coalesce ( p.buffer_gets, 0 ) >= 0 THEN c.buffer_gets - coalesce ( p.buffer_gets, 0 )
            ELSE c.buffer_gets
            END AS buffer_gets,
        CASE
            WHEN c.cpu_time - coalesce ( p.cpu_time, 0 ) >= 0 THEN c.cpu_time - coalesce ( p.cpu_time, 0 )
            ELSE c.cpu_time
            END AS cpu_time,
        CASE
            WHEN c.physical_read_requests - coalesce ( p.physical_read_requests, 0 ) >= 0 THEN
                c.physical_read_requests - coalesce ( p.physical_read_requests, 0 )
            ELSE c.physical_read_requests
            END AS physical_read_requests,
        CASE
            WHEN c.physical_read_bytes - coalesce ( p.physical_read_bytes, 0 ) >= 0 THEN
                c.physical_read_bytes - coalesce ( p.physical_read_bytes, 0 )
            ELSE c.physical_read_bytes
            END AS physical_read_bytes,
        CASE
            WHEN c.physical_write_requests - coalesce ( p.physical_write_requests, 0 ) >= 0 THEN
                c.physical_write_requests - coalesce ( p.physical_write_requests, 0 )
            ELSE c.physical_write_requests
            END AS physical_write_requests,
        CASE
            WHEN c.physical_write_bytes - coalesce ( p.physical_write_bytes, 0 ) >= 0 THEN
                c.physical_write_bytes - coalesce ( p.physical_write_bytes, 0 )
            ELSE c.physical_write_bytes
            END AS physical_write_bytes,
        CASE
            WHEN c.session_logical_io - coalesce ( p.session_logical_io, 0 ) >= 0 THEN
                c.session_logical_io - coalesce ( p.session_logical_io, 0 )
            ELSE c.session_logical_io
            END AS session_logical_io,
        CAST ( substr ( sql.sql_fulltext, 1, 4000 ) AS varchar2 ( 4000 char ) ) AS sql_text
    FROM db_dashboard.curr_sql_activity c
    CROSS JOIN db_dashboard.curr_polling_date cpd
    CROSS JOIN db_dashboard.prev_polling_date ppd
    LEFT JOIN db_dashboard.prev_sql_activity p
        ON ( p.username = c.username
            AND p.address = c.address
            AND p.hash_value = c.hash_value )
    JOIN v$sql sql
        ON ( sql.address = c.address
            AND sql.hash_value = c.hash_value )
    WHERE ( c.elapsed_time <> coalesce ( p.elapsed_time, 0 )
            OR c.fetches <> coalesce ( p.fetches, 0 )
            OR c.executions <> coalesce ( p.executions, 0 )
            OR c.rows_processed <> coalesce ( p.rows_processed, 0 )
            OR c.cpu_time <> coalesce ( p.cpu_time, 0 ) )
        AND sql.parsing_schema_name NOT IN ( 'SYS' )
        AND c.username NOT IN ( 'SYS' )
        AND NOT regexp_like ( upper ( trim ( sql.sql_text ) ), '^ *(CREATE|ALTER).+IDENTIFIED +BY' ) ;

