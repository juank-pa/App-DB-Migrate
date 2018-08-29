package Migrate::Migrations;

use strict;
use warnings;

use Migrate::Factory qw(id);
use Migrate::Config;

sub migrations_table_name { id(Migrate::Config::config->{migrations_table} // '_migrations') }

sub create_migrations_table_sql;
sub select_migrations_sql;
sub insert_migration_sql;
sub delete_migration_sql;

return 1;
