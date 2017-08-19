CREATE VIEW db_dashboard.v_sql_activity AS
WITH a AS (
    SELECT sess.username,
            sess.osuser,
            sess.sid,
            max ( sess.fixed_table_sequence ) AS fixed_table_sequence,
            sess.sql_address AS address,
            sess.sql_hash_value AS hash_value,
            sess.sql_id
        FROM v$session sess
        GROUP BY sess.username,
            sess.osuser,
            sess.sid,
            sess.sql_address,
            sess.sql_hash_value,
            sess.sql_id
),
b AS (
    SELECT sess.username,
            sess.osuser,
            sess.sid,
            max ( sess.fixed_table_sequence ) AS fixed_table_sequence,
            sess.prev_sql_addr AS address,
            sess.prev_hash_value AS hash_value,
            sess.sql_id
        FROM v$session sess
        GROUP BY sess.username,
            sess.osuser,
            sess.sid,
            sess.prev_sql_addr,
            sess.prev_hash_value,
            sess.sql_id
),
c AS (
    SELECT *
        FROM a
    UNION
    SELECT *
        FROM b
)
SELECT coalesce ( c.username, sql.parsing_schema_name ) AS username,
        coalesce ( c.osuser, '--' ) AS osuser,
        sysdate AS polling_dt,
        max ( coalesce ( c.fixed_table_sequence, 0 ) ) AS fixed_table_sequence,
        sql.address,
        sql.hash_value,
        sql.sql_id,
        max ( sql.fetches ) AS fetches,
        max ( sql.executions ) AS executions,
        max ( sql.elapsed_time ) AS elapsed_time,
        max ( sql.rows_processed ) AS rows_processed,
        max ( sql.sharable_mem ) AS sharable_mem,
        max ( sql.persistent_mem ) AS persistent_mem,
        max ( sql.runtime_mem ) AS runtime_mem,
        max ( sql.disk_reads ) AS disk_reads,
        max ( sql.direct_writes ) AS direct_writes,
        max ( sql.buffer_gets ) AS buffer_gets,
        max ( sql.cpu_time ) AS cpu_time,
        max ( sql.physical_read_requests ) AS physical_read_requests,
        max ( sql.physical_read_bytes ) AS physical_read_bytes,
        max ( sql.physical_write_requests ) AS physical_write_requests,
        max ( sql.physical_write_bytes ) AS physical_write_bytes,
        sum ( stat.value ) AS session_logical_io
    FROM v$sql sql
    LEFT JOIN c
        ON ( c.address = sql.address
            AND c.hash_value = sql.hash_value )
    LEFT JOIN v$sesstat stat
        ON stat.sid = c.sid
    LEFT JOIN v$sysstat sys
        ON ( stat.statistic = sys.statistic#
            AND upper ( sys.name ) LIKE '%LOGICAL%' )
    WHERE sql.parsing_schema_name NOT IN ( 'SYS' )
        AND c.username NOT IN ( 'SYS' )
    GROUP BY coalesce ( c.username, sql.parsing_schema_name ),
        coalesce ( c.osuser, '--' ),
        sql.address,
        sql.hash_value,
        sql.sql_id,
        sql.sql_text ;

