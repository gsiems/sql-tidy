CREATE OR REPLACE FUNCTION testing.f_test1 (
    p_parm_1 varchar2,
    p_parm_2 number,
    p_parm_3 varchar2 DEFAULT NULL )
RETURN number
IS

    ln_standard_id number ;
    ln_other_id number ;

BEGIN

    IF some_parm = 'foo' THEN

        SELECT t1.standard_id,
                t2.other_id
            INTO ln_standard_id,
                ln_other_id
            FROM testing.table1 t1,
                testing.table2 t2
            JOIN testing.table3 t3
                ON ( t3.t1_id = t1.id
                    AND t3.t1_tag = t1.tag
                    AND t3.tag2 = t1.tag2 )
            JOIN testing.table4 t4
                ON t4.id = t1.id
                AND t4.status = 'Doh!'
            WHERE t1.standard_id = t2.standard_id
                AND t1.some_num = p_parm_2
                AND t1.parm_id = p_parm_1
                AND t3.some_date BETWEEN sysdate AND sysdate + 2
                AND t2.some_code = coalesce ( p_parm_3, 'Doh!' ) ;

    ELSIF some_parm = 'bar' THEN

        CASE
            WHEN p_parm_2 < 10 THEN ln_standard_id := 1 ;
            WHEN p_parm_2 < 20 THEN ln_standard_id := 2 ;
            ELSE ln_standard_id := 2 ;
        END ;

    ELSE

        ln_standard_id := 0 ;

    END IF ;

    RETURN ln_standard_id ;

EXCEPTION
    WHEN no_data_found THEN
        RETURN -1 ;
    WHEN other THEN
        RETURN -2 ;
END ;
/
