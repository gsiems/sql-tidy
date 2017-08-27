-- multiple sequential decodes
SELECT 1,
        2,
        3 AS col_3,
        decode ( col4,
                1, 'A',
                2, 'B',
                3, 'C',
                'X' )
            || decode ( col5,
                4, 'D',
                5, 'E',
                6, 'F',
                'Y' ) AS col_4
    FROM dual ;

