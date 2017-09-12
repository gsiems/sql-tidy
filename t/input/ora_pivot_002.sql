SELECT *
    FROM (
        SELECT some_id,
                another_id,
                some_code,
                a_third_id,
                some_other_code,
                np_a,
                np_b,
                np_c,
                np_d,
                np_e
            FROM table_01
        )
    PIVOT ( sum ( np_a ) AS np_a,
            sum ( np_b ) AS np_b,
            sum ( np_c ) AS np_c,
            sum ( np_d ) AS np_d,
            sum ( np_e ) AS np_e
        FOR ( some_code ) IN (
            'AA' AS c_aa,
            'AB' AS c_ab,
            'AC' AS c_ac,
            'AD' AS c_ad,
            'AE' AS c_ae,
            'AF' AS c_af,
            'AG' AS c_ag,
            'AH' AS c_ah,
            'AI' AS c_ai,
            'AJ' AS c_aj,
            'AK' AS c_ak,
            'AL' AS c_al,
            'AM' AS c_am,
            'AN' AS c_an,
            'AO' AS c_ao,
            'AP' AS c_ap,
            'AQ' AS c_aq,
            'AR' AS c_ar,
            'AS' AS c_as,
            'AT' AS c_at,
            'AU' AS c_au,
            'AV' AS c_av ) ) ;
