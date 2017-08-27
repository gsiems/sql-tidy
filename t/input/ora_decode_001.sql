SELECT 1,
        2,
        3 AS col_3,
        decode ( col4,
                1, 'A',
                2, 'B',
                3, 'C',
                'X' ) AS col_4
    FROM dual ;

