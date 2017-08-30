/*
Derived from actual code. Ick. A little coalesce and CASE would be soo much cleaner.

*/
SELECT 'a',
        decode ( substr ( table_1.id, 1, 2 ),
                'SA', 'SA' || lpad ( substr ( table_1.id, instr ( table_1.id, 'A' ) + 1 ), 7, '0' ),
                table_1.id )
            || ' - ' || substr ( table_3.name, 1, 52 ) AS title_desc,
        decode ( max ( table_2.code_a ),
                'CODEA', decode ( max ( table_2.end_date ),
                        NULL, decode ( max ( table_2.start_date ),
                                NULL, decode ( max ( table_2.rec_flag ),
                                        'Y', '003',
                                        '001' ),
                                '003' ),
                        '100' ),
                'CODEB', decode ( max ( table_2.end_date ),
                        NULL, '001',
                        '100' ),
                decode ( max ( table_2.start_date ),
                        NULL, '001',
                        '100' ) )
            act_stat_cd,
        decode ( max ( table_2.code_a ),
                'CODEA', nvl ( max ( table_2.end_date ), nvl ( max ( table_2.start_date ), max ( table_2.created_date ) ) ),

            -- delightful nested nvl statements!
            'CODEB', decode ( max ( table_2.end_date ),
                    NULL, nvl ( max ( table_2.start_date ), max ( table_2.created_date ) ), max ( table_2.end_date ) ), decode ( max ( table_2.start_date ),
                    NULL, max ( table_2.created_date ),
                    max ( table_2.start_date ) ) ) act_stat_dt,
        max ( updated_date ),
        max ( created_date ),
        42
    FROM schema_1.table_2
    JOIN schema_1.table_3
        ON ( table_2.id = table_3.id ) ;
