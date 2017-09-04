-- params: convert_decode=1
-- multiple sequential decodes
SELECT 1,
        2,
        3 AS col_3,
        CASE col4
            WHEN 1 THEN 'A'
            WHEN 2 THEN 'B'
            WHEN 3 THEN 'C'
            ELSE 'X'
            END
            || CASE col5
                WHEN 4 THEN 'D'
                WHEN 5 THEN 'E'
                WHEN 6 THEN 'F'
                ELSE 'Y'
                END AS col_4
    FROM dual ;

