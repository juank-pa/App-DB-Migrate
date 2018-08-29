package Migrate::SQLite::Migrations;

use strict;
use warnings;

use parent qw(Migrate::Migrations);

sub create_migrations_table_sql { 'CREATE TABLE IF NOT EXISTS '.shift->migrations_table_name.' (id VARCHAR(128) NOT NULL PRIMARY KEY)' }
sub select_migrations_sql { 'SELECT * FROM '.shift->migrations_table_name.' ORDER BY id' };
sub insert_migration_sql { 'INSERT INTO '.shift->migrations_table_name.' (id) VALUES (?)' }
sub delete_migration_sql { 'DELETE FROM '.shift->migrations_table_name.' WHERE id = ?' }

return 1;
