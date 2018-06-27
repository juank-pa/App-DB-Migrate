package Migrate::Common;

our $script_dir;

use strict;
use warnings;
use feature 'say';

use Log;
use Dbh;
use Getopt::Std;

use Migrate::Generate;
use Migrate::Status;
use Migrate::Run;
use Migrate::Rollback;
use Migrate::Setup;
use Migrate::Informix::Handler;

use List::Util qw(max);
use Module::Load;

our $action;
use constant ACTION_OPTIONS => {
    generate => 'tr:c:n:',
    status => 'f',
    run => '',
    rollback => '',
    setup => '',
};

use feature "switch";

sub run_migration (_);

sub execute
{
    $script_dir = shift;
    $action = shift @ARGV;

    checkEmptyAction();
    checkValidAction();

    pushBackOptions();

    my %options;
    return unless getopts(&actionOptions, \%options);

    checkSetup($action);

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
    say($_->[0], "@{$_->[1]}") foreach @sql;
    return;
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
    if (isOption($action)) {
        undef $action;
        push(@ARGV, $action);
    }
}

sub isOption { shift =~ qr/^_/ }

sub actionOptions { $action && ACTION_OPTIONS->{$action} // '' }
sub actions { keys ACTION_OPTIONS }

sub checkEmptyAction
{
    if (!$action) {
        Migrate::Help::execute();
        exit 0;
    }
}

sub checkValidAction
{
    my $actions = join('|', &actions);
    unless ($action =~ qr/$actions/ || isOption($action)) {
        say("Invalid action: $action");
        exit 0;
    }
}

sub checkSetup
{
    if ($action ne 'setup' && ! Migrate::Setup::isSetup) {
        say('Migrations are not yet setup. Run: migrate setup');
        exit(0);
    }
}

return 1;
