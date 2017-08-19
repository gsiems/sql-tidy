CREATE VIEW db_dashboard.v_session_temp_space AS
WITH tmp AS (
    SELECT b.session_addr,
            b.tablespace,
            sum ( b.blocks ) AS used_blocks,
            sum ( b.blocks * p.value ) AS used_bytes
        FROM v$sort_usage b
        JOIN v$parameter p
            ON ( p.name = 'db_block_size' )
        GROUP BY b.session_addr,
            b.tablespace
)
SELECT b.tablespace,
        b.used_blocks,
        b.used_bytes,
        a.saddr,
        a.sid,
        a.serial AS serial_num,
        a.username,
        a.osuser,
        a.program,
        a.status,
        a.sql_address,
        a.sql_hash_value,
        CAST ( substr ( s.sql_fulltext, 1, 4000 ) AS varchar2 ( 4000 char ) ) AS sql_text
    FROM v$session a
    JOIN tmp b
        ON ( a.saddr = b.session_addr )
    LEFT JOIN v$sql s
        ON ( a.sql_address = s.address
            AND a.sql_hash_value = s.hash_value )
    WHERE a.status = 'ACTIVE' ;

COMMENT ON TABLE db_dashboard.v_session_temp_space IS 'Temp space use by active sessions' ;
