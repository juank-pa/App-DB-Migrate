package App::DB::Migrate::Migrations;

use strict;
use warnings;

use App::DB::Migrate::Factory qw(id);
use App::DB::Migrate::Config;

sub migrations_table_name { id(App::DB::Migrate::Config::config->{migrations_table} // '_migrations') }

sub create_migrations_table_sql;
sub select_migrations_sql;
sub insert_migration_sql;
sub delete_migration_sql;

return 1;
