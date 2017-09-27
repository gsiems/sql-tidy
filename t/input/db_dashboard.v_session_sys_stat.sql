CREATE OR REPLACE FORCE VIEW db_dashboard.v_session_sys_stat (
    sid,
    name,
    value )
AS
SELECT stat.sid,
        s.name,
        stat.value
    FROM v$sesstat stat
    JOIN v$sysstat s
        ON ( stat.statistic = s.statistic# )
    WHERE s.name IN (
            'bytes received via SQL*Net from client', 'bytes received via SQL*Net from dblink',
            'bytes sent via SQL*Net to client', 'bytes sent via SQL*Net to dblink', 'consistent changes',
            'consistent gets', 'consistent gets from cache', 'db block changes', 'db block gets',
            'db block gets from cache', 'physical read bytes', 'physical reads', 'physical reads cache',
            'physical read total bytes', 'physical write bytes', 'physical writes', 'physical write total bytes',
            'redo buffer allocation retries', 'session logical reads' ) ;

COMMENT ON TABLE db_dashboard.v_session_sys_stat IS 'Stats of interest by session' ;

