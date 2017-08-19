CREATE VIEW db_dashboard.v_blocking_locks AS
SELECT waiter.sid AS waiting_sid,
        waiter.serial AS waiting_serial,
        waiter.username AS waiting_user,
        waiter.osuser AS waiting_osuser,
        waiter.event AS waiting_event,
        blocker.sid AS blocking_sid,
        blocker.serial AS blocking_serial,
        blocker.username AS blocking_user,
        blocker.osuser AS blocking_osuser,
        blocker.machine AS blocking_machine,
        blocker.program AS blocking_program,
        CASE
            WHEN obj.owner IS NOT NULL THEN
                CAST ( substr ( obj.owner || '.' || obj.object_name, 1, 60 ) AS varchar2 ( 60 ) )
            END AS locked_object,
        CAST ( substr ( sql.sql_fulltext, 1, 4000 ) AS varchar2 ( 4000 char ) ) AS blocking_sql_text
    FROM v$session waiter
    JOIN v$session blocker
        ON ( waiter.blocking_session = blocker.sid )
    LEFT JOIN v$sql sql
        ON ( sql.address = blocker.sql_address
            AND sql.hash_value = blocker.sql_hash_value )
    LEFT JOIN dba_objects obj
        ON ( obj.object_id = coalesce ( blocker.plsql_entry_object_id, waiter.row_wait_obj ) )
    WHERE waiter.blocking_session_status = 'VALID' ;

