CREATE TABLE db_dashboard.ddl_history (
    object_owner varchar2 ( 255 ),
    object_type varchar2 ( 255 ),
    object_name varchar2 ( 255 ),
    version_control_date date,
    ddl_date date,
    ddl_username varchar2 ( 255 ),
    ddl_os_user varchar2 ( 255 ),
    ddl_host varchar2 ( 255 ),
    ddl_terminal varchar2 ( 255 ),
    sysevent varchar2 ( 30 ) ) ;

CREATE OR REPLACE TRIGGER db_dashboard.record_ddl_history
    AFTER DDL ON DATABASE

BEGIN
    IF ( ora_sysevent <> 'TRUNCATE' ) THEN

        INSERT INTO db_dashboard.ddl_history (
                object_owner,
                object_type,
                object_name,
                ddl_date,
                ddl_username,
                ddl_os_user,
                ddl_host,
                ddl_terminal,
                sysevent )
            VALUES (
                ora_dict_obj_owner,
                ora_dict_obj_type,
                ora_dict_obj_name,
                sysdate,
                user,
                sys_context ( 'USERENV', 'OS_USER' ),
                sys_context ( 'USERENV', 'HOST' ),
                sys_context ( 'USERENV', 'TERMINAL' ),
                ora_sysevent ) ;

    END IF ;

END ;
/
