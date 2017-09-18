-- CASE statements with wrapping conditions
SELECT CASE
            WHEN ( a.yes_no_maybe_flag = 'Y' AND b.yes_no_maybe_flag = 'Y' )
                    OR ( c.yes_no_maybe_flag = 'Y' AND d.yes_no_maybe_flag = 'Y' ) THEN 'Y'
            ELSE 'N'
            END AS yes_no_flag,
        CASE
            WHEN column_01 = 10 * sum ( 1 ) OVER (
                PARTITION BY table_01.component_id
                ORDER BY table_01.column_zero_2, table_01.column_zero_1
                RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) THEN 'good'
            ELSE 'bad'
            END AS error_flag,
        CASE
            WHEN substr ( column_01, 1, 3 ) = 'A' THEN 'dog'
            WHEN substr ( column_01, 1, 2 ) = 'B' THEN 'cat'
            WHEN substr ( column_01, 1, 2 ) = 'C'
                    AND substr ( column_01, 4, 5 ) NOT IN ( 'D', 'E' )
                    AND substr ( column_03, 4, 5 ) NOT IN ( 'F', 'G' ) THEN 'fish'
            END AS z1,
        CASE
            WHEN table_01.x_coord_standard_value IS NULL
                    AND to_number ( regexp_substr ( trim ( table_01.x_coord_value ), '^-?(\d+)?(\.\d*)?$' ) ) < -80
                    AND to_number ( regexp_substr ( trim ( table_01.x_coord_value ), '^-?(\d+)?(\.\d*)?$' ) ) > -100
                    AND table_01.coordinate_system_code = '02' THEN
                to_number ( regexp_substr ( trim ( table_01.x_coord_value ), '^-?(\d+)?(\.\d*)?$' ) )
            ELSE table_01.x_coord_standard_value
            END AS longitude,
        CASE
            WHEN table_01.some_id = 1066 THEN
                ( substr ( table_02.some_such_type_code, 0, 3 ) || ': ' || table_02.some_other_value || ' '
                    || table_02.yet_another_code || 'lorum ipsum' || substr ( table_03.something_something_code, 0, 3 )
                    || ': ' || table_03.some_such_type_code || table_03.text_column_03 )
            ELSE table_01.some_such_code || ': ' || table_01.some_such_value || ' ' || table_02.some_other_code
            END AS z2,
        CASE
            WHEN ( ( table_01.column_a + table_01.column_b ) / coalesce ( table_01.column_c, 0 ) )
                    + ( ( table_02.column_a + table_02.column_b ) * coalesce ( table_02.column_c, 1 ) )
                    > ( table_03.column_a + table_03.column_b ) THEN 42
            END AS z3,
        column_02
    FROM table_01
    JOIN table_02
        ON ( table_02.parent_id = table_01.id )
