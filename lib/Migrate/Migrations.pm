package Migrate::Migrations;

use strict;
use warnings;

use Migrate::Util;

sub migrations_table_name { '_migrations' }

sub create_migrations_table_sql { }
sub select_migrations_sql { }
sub insert_migration_sql { }
sub delete_migration_sql { }

return 1;
