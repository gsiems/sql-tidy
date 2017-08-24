CREATE TRIGGER table1_bi
    BEFORE INSERT ON schema1.table1
    REFERENCING NEW AS NEW OLD AS OLD
    FOR EACH ROW

BEGIN
    IF :new.id IS NULL THEN

        SELECT sys_guid ()
            INTO :new.id
            FROM dual ;

    END IF ;

    :new.tmsp_last_updt := sysdate ;
    :new.tmsp_created := sysdate ;

    IF :new.user_last_updt IS NULL THEN
        :new.user_last_updt := user ;

    END IF ;

END table1_bi ;
/
