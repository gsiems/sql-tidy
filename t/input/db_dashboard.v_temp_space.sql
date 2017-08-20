DROP VIEW db_dashboard.v_temp_space ;

CREATE VIEW db_dashboard.v_temp_space
AS
SELECT b.tablespace,
        b.segfile AS seg_file_num,
        b.segblk AS seg_block_num,
        b.blocks AS used_blocks,
        b.blocks * p.value AS used_bytes,
        a.sid,
        a.serial AS serial_num,
        a.username,
        a.osuser,
        a.program,
        a.status,
        CAST ( sql.address AS varchar2 ( 50 ) ) AS address_text,
        sql.hash_value,
        sql.sql_id,
        CAST ( substr ( sql.sql_fulltext, 1, 4000 ) AS varchar2 ( 4000 char ) ) AS sql_text
    FROM "V$SESSION" a
    JOIN "V$SORT_USAGE" b
        ON ( a.saddr = b.session_addr )
    JOIN "V$PARAMETER" p
        ON ( p.name = 'db_block_size' )
    LEFT JOIN "V$SQL" sql
        ON ( a.sql_address = sql.address
            AND a.sql_hash_value = sql.hash_value ) ;

