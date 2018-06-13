package Migrate::Common;

use strict;
use warnings;
use Log;
use Dbh;
use File::Path qw(make_path);
use Getopt::Std;

use Migrate::Generate;

our $action;
use constant ACTIONS => qw{generate status run rollback};
use constant ACTION_OPTIONS => {
    generate => 'tr:c:n:',
    status => '',
    run => '',
    rollback => '',
};

use feature "switch";

sub execute
{
    $action = shift @ARGV;

    checkEmptyAction();
    checkValidAction();

    pushBackOptions();

    my %options;
    return unless getopts(&actionOptions, \%options);

    my $execute_sub = \&{"Migrate::\u${action}::execute"};
    $execute_sub->(\%options);
}

sub pushBackOptions
{
    if ($action =~ qr/^-/) {
        undef $action;
        push(@ARGV, $action);
    }
}

sub actionOptions { $action && ACTION_OPTIONS->{$action} // '' }

sub checkEmptyAction
{
    if (!$action) {
        Migrate::Help::execute();
        exit 0;
    }
}

sub checkValidAction
{
    my $actions = join('|', ACTIONS);
    unless ($action =~ qr/$actions/ || $action =~ qr/^-/) {
        Log::warn("Invalid action: $action");
        exit 0;
    }
}

sub initMigrations
{
    my $dbh = shift;
    createMigrationsFolder();
    if (migrationsTableExists($dbh)) { Log::debug('Its alive!!'); return; }
    createMigrationsTableQuery($dbh);
}

sub createMigrationsFolder
{
    eval { make_path("./migrations") };
    if ($@) {
        Log::debug("Could not create migrations directory!");
    }
}

sub createMigrationsTableQuery
{
    my $dbh = shift;
    my @sql = (<<CREATE, <<INDEX, <<PK);
CREATE TABLE "$Dbh::DBSchema"._migrations (
    migration_id varchar(128)
);
CREATE
CREATE UNIQUE INDEX "$Dbh::DBSchema".xu1_migrations_migration_id on _migrations (migration_id);
INDEX
ALTER TABLE "$Dbh::DbSchema"._migrations add constraint primary key (migration_id) constraint "$Dbh::DbSchema".pk_migrations;
PK
    Dbh::doSQL($_, {}, $dbh) foreach @sql;
}

sub migrationsTableExists
{
    my $dbh = shift;
    my $fields = { tabname => '_migrations' };
    Dbh::runSQL(Dbh::query('systables', $fields), $fields, $dbh);
}

return 1;
