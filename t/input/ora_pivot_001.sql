SELECT *
    FROM (
        SELECT t1m.id,
                t1m.group_id,
                piv.c_black,
                piv.c_brown,
                piv.c_red,
                piv.c_orange,
                piv.c_yellow,
                piv.c_green,
                piv.c_blue,
                piv.c_violet
            FROM (
                SELECT id,
                        c_black,
                        c_brown,
                        c_red,
                        c_orange,
                        c_yellow,
                        c_green,
                        c_blue,
                        c_violet
                    FROM (
                        SELECT color_code,
                                id
                            FROM schema1.wild_attribute wa
                        )
                    PIVOT ( max ( color_code )
                        FOR color_code IN (
                            'BLACK' AS c_black,
                            'BROWN' AS c_brown,
                            'RED' AS c_red,
                            'ORANGE' AS c_orange,
                            'YELLOW' AS c_yellow,
                            'GREEN' AS c_green,
                            'BLUE' AS c_blue,
                            'VIOLET' AS c_violet ) )
                ) piv
            INNER JOIN (
                SELECT DISTINCT t1.id,
                        t2.group_id
                    FROM schema1.table1 t1
                    INNER JOIN schema1.table2 t2
                        ON t1.id = t2.id
                        AND t1.status = 'NEW'
                        AND t1.type = 'BRIGHT'
                ) t1m
                ON piv.id = t1m.id
        ) ;
