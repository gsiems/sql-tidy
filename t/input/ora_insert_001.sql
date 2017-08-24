INSERT INTO schema1.table10
    SELECT table1.column1
        FROM schema1.table1 table1
        WHERE table1.id_2 <> 0
            AND table1.id_3 = 6
    UNION
    -- bah, blah, blah
    SELECT table1.column1
        FROM schema1.table_2 t2,
            schema1.table_3 t3
        WHERE table1.id_2 <> 0
            AND table1.id_3 = 6
            AND table1.id_2 = t3.id_2
    MINUS -- bah, blah, blah
    SELECT table1.column1
        FROM schema1.table_2 t2,
            schema1.table_3 t3
        WHERE table1.id_2 <> 0
            AND table1.id_3 = 6
            AND table1.id_2 = t3.id_2 ;

