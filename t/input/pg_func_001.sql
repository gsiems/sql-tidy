CREATE OR REPLACE FUNCTION pip__delete (
    _id integer )
RETURNS boolean
SECURITY DEFINER
LANGUAGE plpgsql
AS $$

BEGIN

    DELETE FROM pt_pip_category
        WHERE pip_id = _id ;

    DELETE FROM pt_pip_tag
        WHERE pip_id = _id ;

    DELETE FROM pt_pip
        WHERE id = _id ;

    RETURN true ;
END ;
$$ ;

ALTER FUNCTION pip__delete ( integer ) OWNER TO ptrack_updater ;

GRANT EXECUTE ON pip__delete ( integer ) TO ptrack_user ;
