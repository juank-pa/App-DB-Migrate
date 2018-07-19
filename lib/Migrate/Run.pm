package Migrate::Run;

use strict;
use warnings;
use feature 'say';

use Migrate::Dbh qw(get_dbh);
use Migrate::Factory qw(create);
use Data::Dumper;

sub run {
    Migrate::Setup::setup_migrations_table();
    _run_migrations('down', -1)
}

sub rollback {
    Migrate::Setup::setup_migrations_table();
    _run_migrations('up', shift)
}

sub _run_migrations {
    my $filter = shift;
    my @migrations = _filtered_migrations($filter, @_);
    _run_migration($_) foreach @migrations;
}

sub _filtered_migrations {
    my $filter = shift;
    my $steps = shift // 1;

    my @migrations = (grep { $_->{status} eq $filter } Migrate::Status::get_migrations());
    $steps = scalar(@migrations) if $steps < 0;
    @migrations = reverse @migrations if $filter eq 'up';

    return @migrations[0 .. $steps - 1];
}

sub _run_migration {
    my $migration = shift;
    my $function = $migration->{status} eq 'down'? 'up' : 'down';
    my $handler = create('handler');

    _run_migration_function($migration->{path}, $function, $handler);

    die($@) if $@;

    my @sql = @{$handler->{sql}};
    say($_) foreach @sql;
    return;

    my $dbh = get_dbh();
    $dbh->begin_work;

    $dbh->do($_) foreach @sql;
    _record_migration($function, $migration->{id}, $dbh);

    return $dbh->commit unless $@;

    die($@->errstr);
    $dbh->rollback;
}

sub _run_migration_function {
    my ($path, $function, $handler) = @_;
    eval {
        package Migrate::Migration;
        no strict 'refs';
        do($path);
        "Migrate::Migration::$function"->($handler);
    };
}

sub _record_migration {
    my ($function, $id, $dbh) = @_;

    if ($function eq 'up') {
        $dbh->prepare(class('migrations')->insert_migration_sql)->execute($id);
    }
    else {
        $dbh->prepare(class('migrations')->delete_migration_sql)->execute($id);
    }
}

return 1;
