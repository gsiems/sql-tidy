CREATE VIEW db_dashboard.v_session_query_stat (
    username,
    osuser,
    polling_dt,
    sql_address_source,
    status,
    temp_used_bytes,
    address,
    hash_value,
    sql_id,
    fetches,
    executions,
    elapsed_time,
    rows_processed,
    sharable_mem,
    persistent_mem,
    runtime_mem,
    disk_reads,
    direct_writes,
    buffer_gets,
    cpu_time,
    physical_read_requests,
    physical_read_bytes,
    physical_write_requests,
    physical_write_bytes,
    sql_text ) AS
WITH tmp AS (
    SELECT b.saddr,
            sum ( b.used_bytes ) AS used_bytes
        FROM db_dashboard.session_temp_space b
        GROUP BY b.saddr
),
curr AS (
    SELECT sess.saddr,
            sess.username,
            sess.osuser,
            sess.sid,
            sess.status,
            CASE
                WHEN sess.status = 'ACTIVE' THEN tmp.used_bytes
                ELSE 0
                END AS used_bytes,
            sess.sql_address,
            sess.sql_hash_value,
            sess.sql_id
        FROM v$session sess
        LEFT JOIN tmp
            ON ( tmp.saddr = sess.saddr )
        WHERE sess.username NOT IN ( 'SYS' )
),
prev AS (
    -- Since we only query periodically (1 min.), we want to get as
    -- much history as we can without using any of the "problematic"
    -- history tables...
    SELECT sess.saddr,
            sess.username,
            sess.osuser,
            sess.sid,
            sess.status,
            sess.prev_sql_addr AS sql_address,
            sess.prev_hash_value AS sql_hash_value,
            sess.sql_id
        FROM v$session sess
        WHERE sess.username NOT IN ( 'SYS' )
),
q AS (
    -- Sometimes the current matches the previous, in which case we don't
    -- want duplicates. We may also want to know current vs. previous.
    -- Using CASE vs. coalesce as we don't want to mix and match between
    -- prev and current.
    SELECT
            CASE
                WHEN curr.saddr IS NOT NULL THEN curr.saddr
                ELSE prev.saddr
                END AS saddr,
            CASE
                WHEN curr.saddr IS NOT NULL THEN curr.username
                ELSE prev.username
                END AS username,
            CASE
                WHEN curr.saddr IS NOT NULL THEN curr.osuser
                ELSE prev.osuser
                END AS osuser,
            CASE
                WHEN curr.saddr IS NOT NULL THEN curr.sid
                ELSE prev.sid
                END AS sid,
            CASE
                WHEN curr.saddr IS NOT NULL THEN curr.status
                ELSE prev.status
                END AS status,
            CASE
                WHEN curr.saddr IS NOT NULL THEN curr.used_bytes
                ELSE 0
                END AS used_bytes,
            CASE
                WHEN curr.saddr IS NOT NULL THEN 'curr'
                ELSE 'prev'
                END AS sql_address_source,
            CASE
                WHEN curr.saddr IS NOT NULL THEN curr.sql_address
                ELSE prev.sql_address
                END AS sql_address,
            CASE
                WHEN curr.saddr IS NOT NULL THEN curr.sql_hash_value
                ELSE prev.sql_hash_value
                END AS sql_hash_value,
            CASE
                WHEN curr.saddr IS NOT NULL THEN curr.sql_id
                ELSE prev.sql_id
                END AS sql_id
        FROM curr
        FULL JOIN prev
            ON ( prev.saddr = curr.saddr
                AND prev.username = curr.username
                AND prev.osuser = curr.osuser
                AND prev.sid = curr.sid
                AND prev.sql_address = curr.sql_address
                AND prev.sql_hash_value = curr.sql_hash_value )
        WHERE coalesce ( prev.sql_address, curr.sql_address ) IS NOT NULL
            AND coalesce ( prev.sql_hash_value, curr.sql_hash_value ) <> 0
)
SELECT coalesce ( q.username, s.parsing_schema_name ) AS username,
        coalesce ( q.osuser, '--' ) AS osuser,
        cpd.polling_dt,
        max ( q.sql_address_source ) AS sql_address_source,
        min ( q.status ) AS status,
        max ( coalesce ( q.used_bytes, 0 ) ) AS temp_used_bytes,
        s.address,
        s.hash_value,
        s.sql_id,
        max ( s.fetches ) AS fetches,
        max ( s.executions ) AS executions,
        max ( s.elapsed_time ) AS elapsed_time,
        max ( s.rows_processed ) AS rows_processed,
        max ( s.sharable_mem ) AS sharable_mem,
        max ( s.persistent_mem ) AS persistent_mem,
        max ( s.runtime_mem ) AS runtime_mem,
        max ( s.disk_reads ) AS disk_reads,
        max ( s.direct_writes ) AS direct_writes,
        max ( s.buffer_gets ) AS buffer_gets,
        max ( s.cpu_time ) AS cpu_time,
        max ( s.physical_read_requests ) AS physical_read_requests,
        max ( s.physical_read_bytes ) AS physical_read_bytes,
        max ( s.physical_write_requests ) AS physical_write_requests,
        max ( s.physical_write_bytes ) AS physical_write_bytes,
        CAST ( substr ( s.sql_fulltext, 1, 4000 ) AS varchar2 ( 4000 char ) ) AS sql_text
    FROM v$sql s
    JOIN q
        ON ( s.address = q.sql_address
            AND s.hash_value = q.sql_hash_value )
    CROSS JOIN db_dashboard.curr_polling_date cpd
    WHERE s.parsing_schema_name NOT IN ( 'SYS' )
        AND q.username NOT IN ( 'SYS' )
    GROUP BY coalesce ( q.username, s.parsing_schema_name ),
        coalesce ( q.osuser, '--' ),
        cpd.polling_dt,
        s.address,
        s.hash_value,
        s.sql_id,
        CAST ( substr ( s.sql_fulltext, 1, 4000 ) AS varchar2 ( 4000 char ) ) ;

COMMENT ON TABLE db_dashboard.v_session_query_stat IS 'Session query statistics' ;

