#!/bin/bash
set -e

echo "Loading LMS schema..."
# Schema is copied from doc/lms.pgsql during docker build or volume mount
# If running via docker-compose with volume mount, schema is at /var/www/lms/doc/lms.pgsql
if [ -f /docker-entrypoint-initdb.d/lms.pgsql ]; then
    psql -U lms -d lms -f /docker-entrypoint-initdb.d/lms.pgsql
elif [ -f /lms-schema/lms.pgsql ]; then
    psql -U lms -d lms -f /lms-schema/lms.pgsql
else
    echo "ERROR: LMS schema file not found!"
    exit 1
fi

echo "Creating FreeRADIUS radacct table..."
psql -U lms -d lms <<'EOSQL'

-- FreeRADIUS accounting table (not part of LMS schema)
CREATE TABLE IF NOT EXISTS radacct (
    radacctid bigserial PRIMARY KEY,
    acctsessionid varchar(64) NOT NULL DEFAULT '',
    acctuniquesessionid varchar(32) NOT NULL DEFAULT '',
    username varchar(64) NOT NULL DEFAULT '',
    realm varchar(64) DEFAULT '',
    nasipaddress varchar(15) NOT NULL DEFAULT '',
    nasportid varchar(32) DEFAULT NULL,
    nasporttype varchar(32) DEFAULT NULL,
    acctstarttime timestamp with time zone DEFAULT NULL,
    acctstoptime timestamp with time zone DEFAULT NULL,
    acctsessiontime bigint DEFAULT NULL,
    acctauthentic varchar(32) DEFAULT NULL,
    connectinfo_start varchar(50) DEFAULT NULL,
    connectinfo_stop varchar(50) DEFAULT NULL,
    acctinputoctets bigint DEFAULT NULL,
    acctoutputoctets bigint DEFAULT NULL,
    calledstationid varchar(50) NOT NULL DEFAULT '',
    callingstationid varchar(50) NOT NULL DEFAULT '',
    acctterminatecause varchar(32) NOT NULL DEFAULT '',
    servicetype varchar(32) DEFAULT NULL,
    framedprotocol varchar(32) DEFAULT NULL,
    framedipaddress varchar(15) NOT NULL DEFAULT '',
    acctstartdelay integer DEFAULT NULL,
    acctstopdelay integer DEFAULT NULL
);
CREATE INDEX radacct_acctsessionid ON radacct (acctsessionid);
CREATE INDEX radacct_acctsessiontime ON radacct (acctsessiontime);
CREATE INDEX radacct_acctstarttime ON radacct (acctstarttime);
CREATE INDEX radacct_acctstoptime ON radacct (acctstoptime);
CREATE INDEX radacct_nasipaddress ON radacct (nasipaddress);
CREATE INDEX radacct_username ON radacct (username);
CREATE INDEX radacct_framedipaddress ON radacct (framedipaddress);

-- FreeRADIUS reply table
CREATE TABLE IF NOT EXISTS radreply (
    id serial PRIMARY KEY,
    username varchar(64) NOT NULL DEFAULT '',
    attribute varchar(64) NOT NULL DEFAULT '',
    op char(2) NOT NULL DEFAULT '=',
    value varchar(253) NOT NULL DEFAULT ''
);
CREATE INDEX radreply_username ON radreply (username);

EOSQL

echo "Database initialization complete."
