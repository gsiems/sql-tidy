CREATE OR REPLACE PROCEDURE proc_02
AS

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
/

