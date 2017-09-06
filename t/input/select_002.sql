SELECT table1.col1,
        table1.col2
    FROM table1
    JOIN table2
        ON ( table2.col1 = table1.col1
            AND table2.col2 = table1.col2
            AND table2.col3 = table1.col3
            AND table2.col4 = table1.col4
            AND table2.col5 = table1.col5
            AND table2.col6 = table1.col6 )
    WHERE table2.colx = 'x'
        AND table2.coly = 'y'
        AND table2.colz = 'z' ;
