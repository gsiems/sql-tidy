-- Nested CASE statements, CASE statements with comments
SELECT 'a',
        CASE
            WHEN substr ( table_1.id, 1, 2 ) = 'SA' THEN
                'SA' || lpad ( substr ( table_1.id, instr ( table_1.id, 'A' ) + 1 ), 7, '0' )
            ELSE table_1.id
            END || ' - ' || substr ( table_3.name, 1, 52 ) AS title_desc,
        CASE max ( table_2.code_a )
            WHEN 'CODEA' THEN
                CASE
                    WHEN max ( table_2.end_date ) IS NULL THEN
                        CASE
                            WHEN max ( table_2.start_date ) IS NULL THEN
                                CASE
                                    WHEN max ( table_2.rec_flag ) = 'Y' THEN '003'
                                    ELSE '001'
                                    END
                            ELSE '003'
                            END
                    ELSE '100'
                    END
            WHEN 'CODEB' THEN
                CASE
                    WHEN max ( table_2.end_date ) IS NULL THEN '001'
                    ELSE '100'
                    END
            ELSE
                CASE
                    WHEN max ( table_2.start_date ) IS NULL THEN '001'
                    ELSE '100'
                    END
            END AS act_stat_cd,
        CASE
            WHEN max ( table_2.code_a ) IN ( 'CODEA', 'CODEB' ) THEN
                coalesce ( max ( table_2.end_date ), max ( table_2.start_date ), max ( table_2.created_date ) )
            ELSE coalesce ( max ( table_2.start_date ), max ( table_2.created_date ) )
            END AS act_stat_dt,
        max ( updated_date ),
        max ( created_date ),
        42
    FROM schema_1.table_2
    JOIN schema_1.table_3
        ON ( table_2.id = table_3.id ) ;
--
SELECT 'a',
        CASE
            WHEN substr ( table_1.id, 1, 2 ) = 'SA' THEN
                'SA' || lpad ( substr ( table_1.id, instr ( table_1.id, 'A' ) + 1 ), 7, '0' )
            ELSE table_1.id
            END || ' - ' || substr ( table_3.name, 1, 52 ) AS title_desc,
        CASE
            WHEN max ( table_2.code_a ) = 'CODEA' AND max ( table_2.end_date ) IS NOT NULL THEN '100'
            -- max ( table_2.end_date ) IS NULL
            WHEN max ( table_2.code_a ) = 'CODEA' AND max ( table_2.start_date ) IS NOT NULL THEN '003'
            -- max ( table_2.end_date ) IS NULL AND max ( table_2.start_date ) IS NULL
            WHEN max ( table_2.code_a ) = 'CODEA' AND max ( table_2.rec_flag ) = 'Y' THEN '003'
            WHEN max ( table_2.code_a ) = 'CODEA' THEN '001'
            WHEN max ( table_2.code_a ) = 'CODEB' AND max ( table_2.end_date ) IS NULL THEN '001'
            WHEN max ( table_2.code_a ) = 'CODEB' THEN '100'
            WHEN max ( table_2.start_date ) IS NULL THEN '001'
            ELSE '100'
            END AS act_stat_cd,
        CASE -- Just saying...
            WHEN max ( table_2.code_a ) IN ( 'CODEA', 'CODEB' ) THEN
                coalesce ( max ( table_2.end_date ), max ( table_2.start_date ), max ( table_2.created_date ) )
            ELSE coalesce ( max ( table_2.start_date ), max ( table_2.created_date ) )
            END AS act_stat_dt,
        max ( updated_date ),
        max ( created_date ),
        42
    FROM schema_1.table_2
    JOIN schema_1.table_3
        ON ( table_2.id = table_3.id ) ;
