CREATE OR REPLACE PACKAGE package_01 AS
    PROCEDURE proc_01 (
        an_id table_1.id%type ) ;
    PROCEDURE proc_02 ;
END package_01 ;
/

CREATE OR REPLACE PACKAGE BODY package_01 AS
    PROCEDURE proc_01 (
        an_id table_1.id%type )
    IS

    BEGIN

        INSERT INTO table_2
            SELECT *
                FROM table_1
                WHERE id = an_id ;

        COMMIT ;

    EXCEPTION
        WHEN no_data_found THEN
            RETURN -1 ;
    END ;

    PROCEDURE proc_02
    IS
        PROCEDURE sub_proc_main ;
        PROCEDURE sub_proc_001_01 (
            an_id table_z.id%type,
            another_id table_y.id%type ) ;
        PROCEDURE sub_proc_001_01 (
            an_id table_z.id%type,
            another_id table_y.id%type )
        IS

        BEGIN
        END ;

        PROCEDURE sub_proc_main
        IS

        BEGIN
            sub_proc_001_01 ( 1, 1 ) ;
        END ;

    BEGIN
        sub_proc_main ;
    END ;

END ;
/

