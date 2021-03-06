MERGE INTO db_dashboard.prev_query_stat o
    USING db_dashboard.curr_query_stat n
        ON ( n.username = o.username
            AND n.osuser = o.osuser
            AND n.address = o.address
            AND n.hash_value = o.hash_value )
    WHEN MATCHED THEN
        UPDATE
            SET o.polling_dt = n.polling_dt,
                o.sql_address_source = n.sql_address_source,
                o.status = n.status,
                o.temp_used_bytes = n.temp_used_bytes,
                o.sql_id = n.sql_id,
                o.fetches = n.fetches,
                o.executions = n.executions,
                o.elapsed_time = n.elapsed_time,
                o.rows_processed = n.rows_processed,
                o.sharable_mem = n.sharable_mem,
                o.persistent_mem = n.persistent_mem,
                o.runtime_mem = n.runtime_mem,
                o.disk_reads = n.disk_reads,
                o.direct_writes = n.direct_writes,
                o.buffer_gets = n.buffer_gets,
                o.cpu_time = n.cpu_time,
                o.physical_read_requests = n.physical_read_requests,
                o.physical_read_bytes = n.physical_read_bytes,
                o.physical_write_requests = n.physical_write_requests,
                o.physical_write_bytes = n.physical_write_bytes,
                o.sql_text = n.sql_text
    WHEN NOT MATCHED THEN
        INSERT (
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
                sql_text )
            VALUES (
                n.username,
                n.osuser,
                n.polling_dt,
                n.sql_address_source,
                n.status,
                n.temp_used_bytes,
                n.address,
                n.hash_value,
                n.sql_id,
                n.fetches,
                n.executions,
                n.elapsed_time,
                n.rows_processed,
                n.sharable_mem,
                n.persistent_mem,
                n.runtime_mem,
                n.disk_reads,
                n.direct_writes,
                n.buffer_gets,
                n.cpu_time,
                n.physical_read_requests,
                n.physical_read_bytes,
                n.physical_write_requests,
                n.physical_write_bytes,
                n.sql_text ) ;
