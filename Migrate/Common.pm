package Migrate::Common;

use strict;
use warnings;
use feature 'say';

use Log;
use Dbh;
use File::Path qw(make_path);
use Getopt::Std;

use Migrate::Generate;
use Migrate::Status;
use Migrate::Run;
use Migrate::Rollback;
use Migrate::Informix::Handler;

use List::Util qw(max);
use Module::Load;

our $action;
use constant ACTIONS => qw{generate status run rollback};
use constant ACTION_OPTIONS => {
    generate => 'tr:c:n:',
    status => 'f',
    run => '',
    rollback => '',
};

use feature "switch";

sub run_migration (_);

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

sub migrations_up
{
    run_migrations('down', -1);
}

sub migrations_down
{
    run_migrations('up', shift);
}

sub run_migrations
{
    my $filter = shift;
    my @migrations = filtered_migrations($filter, @_);
    run_migration foreach @migrations;
}

sub filtered_migrations
{
    my $filter = shift;
    my $steps = shift // 1;

    my @migrations = (grep { $_->{status} eq $filter } Migrate::Status::get_migrations());
    $steps = scalar(@migrations) if $steps < 0;
    @migrations = reverse @migrations if $filter eq 'up';

    return @migrations[0 .. $steps - 1];
}

sub run_migration (_)
{
    my $migration = shift;
    my $function = $migration->{status} eq 'down'? 'up' : 'down';

    no strict 'refs';
    load $migration->{path};

    my $handler = Migrate::Handler::get_handler;
    "$migration->{package}::$function"->($handler);

    my $dbh = Dbh::getDBH();
    $dbh->begin_work;

    my @sql = @{$handler->{sql}};
    $dbh->do($_->[0], undef, @{$_->[1]}) foreach @sql;

    if ($function eq 'up') {
        $dbh->do("INSERT INTO _migrations (migration_id) VALUES ('$migration->{id}')");
    }
    else {
        $dbh->do("DELETE FROM _migrations WHERE migration_id = '$migration->{id}'");
    }
    print($@->errstr) if $@;

    $dbh->commit if !$@;
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
    if (migrationsTableExists($dbh)) { return; }
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
