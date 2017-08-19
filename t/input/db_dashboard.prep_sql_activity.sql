CREATE PROCEDURE db_dashboard.prep_sql_activity
AS

BEGIN

    DELETE FROM db_dashboard.prev_polling_date ;

    INSERT INTO db_dashboard.prev_polling_date (
            polling_dt )
        SELECT polling_dt
            FROM db_dashboard.curr_polling_date ;

    DELETE FROM db_dashboard.curr_polling_date ;

    INSERT INTO db_dashboard.curr_polling_date (
            polling_dt )
        SELECT sysdate
            FROM dual ;

    execute immediate 'TRUNCATE TABLE db_dashboard.temp_sql_activity' ;

    INSERT INTO db_dashboard.temp_sql_activity (
            username,
            osuser,
            polling_dt,
            fixed_table_sequence,
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
            session_logical_io )
        SELECT username,
                osuser,
                polling_dt,
                fixed_table_sequence,
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
                session_logical_io
            FROM db_dashboard.v_sql_activity ;

    -- NOTE: max and group by because, every once in awhile, there is an
    --  instance of more than one fixed_table_sequence for a given (
    --  username, osuser, address, hash_value, sql_id )

    MERGE INTO db_dashboard.prev_sql_activity p
        USING (
            SELECT a.username,
                    a.osuser,
                    a.address,
                    a.hash_value,
                    a.sql_id,
                    max ( a.polling_dt ) AS polling_dt,
                    max ( a.fixed_table_sequence ) AS fixed_table_sequence,
                    max ( a.fetches ) AS fetches,
                    max ( a.executions ) AS executions,
                    max ( a.elapsed_time ) AS elapsed_time,
                    max ( a.rows_processed ) AS rows_processed,
                    max ( a.sharable_mem ) AS sharable_mem,
                    max ( a.persistent_mem ) AS persistent_mem,
                    max ( a.runtime_mem ) AS runtime_mem,
                    max ( a.disk_reads ) AS disk_reads,
                    max ( a.direct_writes ) AS direct_writes,
                    max ( a.buffer_gets ) AS buffer_gets,
                    max ( a.cpu_time ) AS cpu_time,
                    max ( a.physical_read_requests ) AS physical_read_requests,
                    max ( a.physical_read_bytes ) AS physical_read_bytes,
                    max ( a.physical_write_requests ) AS physical_write_requests,
                    max ( a.physical_write_bytes ) AS physical_write_bytes,
                    max ( a.session_logical_io ) AS session_logical_io
                FROM db_dashboard.curr_sql_activity a
                GROUP BY a.username,
                    a.osuser,
                    a.address,
                    a.hash_value,
                    a.sql_id
            ) c
            ON ( p.username = c.username
                AND p.osuser = c.osuser
                AND p.address = c.address
                AND p.hash_value = c.hash_value
                AND p.sql_id = c.sql_id )
        WHEN MATCHED THEN
            UPDATE
                SET polling_dt = c.polling_dt,
                    fixed_table_sequence = c.fixed_table_sequence,
                    fetches = c.fetches,
                    executions = c.executions,
                    elapsed_time = c.elapsed_time,
                    rows_processed = c.rows_processed,
                    sharable_mem = c.sharable_mem,
                    persistent_mem = c.persistent_mem,
                    runtime_mem = c.runtime_mem,
                    disk_reads = c.disk_reads,
                    direct_writes = c.direct_writes,
                    buffer_gets = c.buffer_gets,
                    cpu_time = c.cpu_time,
                    physical_read_requests = c.physical_read_requests,
                    physical_read_bytes = c.physical_read_bytes,
                    physical_write_requests = c.physical_write_requests,
                    physical_write_bytes = c.physical_write_bytes,
                    session_logical_io = c.session_logical_io
        WHEN NOT MATCHED THEN
            INSERT (
                    username,
                    osuser,
                    polling_dt,
                    fixed_table_sequence,
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
                    session_logical_io )
                VALUES (
                    c.username,
                    c.osuser,
                    c.polling_dt,
                    c.fixed_table_sequence,
                    c.address,
                    c.hash_value,
                    c.sql_id,
                    c.fetches,
                    c.executions,
                    c.elapsed_time,
                    c.rows_processed,
                    c.sharable_mem,
                    c.persistent_mem,
                    c.runtime_mem,
                    c.disk_reads,
                    c.direct_writes,
                    c.buffer_gets,
                    c.cpu_time,
                    c.physical_read_requests,
                    c.physical_read_bytes,
                    c.physical_write_requests,
                    c.physical_write_bytes,
                    c.session_logical_io ) ;

    COMMIT ;
    execute immediate 'TRUNCATE TABLE db_dashboard.curr_sql_activity' ;

    INSERT INTO db_dashboard.curr_sql_activity (
            username,
            osuser,
            polling_dt,
            fixed_table_sequence,
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
            session_logical_io )
        SELECT username,
                osuser,
                polling_dt,
                fixed_table_sequence,
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
                session_logical_io
            FROM db_dashboard.temp_sql_activity ;

    COMMIT ;
    execute immediate 'TRUNCATE TABLE db_dashboard.temp_sql_activity' ;
END ;
/

