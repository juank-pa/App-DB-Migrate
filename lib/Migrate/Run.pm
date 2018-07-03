package Migrate::Run;

use strict;
use warnings;

use Migrate::Dbh;
use Migrate::Handler;

sub execute_up {
    run_migrations('down', -1);
}

sub execute_down {
    run_migrations('up', shift);
}

sub run_migrations {
    my $filter = shift;
    my @migrations = filtered_migrations($filter, @_);
    run_migration() foreach @migrations;
}

sub filtered_migrations {
    my $filter = shift;
    my $steps = shift // 1;

    my @migrations = (grep { $_->{status} eq $filter } Migrate::Status::get_migrations());
    $steps = scalar(@migrations) if $steps < 0;
    @migrations = reverse @migrations if $filter eq 'up';

    return @migrations[0 .. $steps - 1];
}

sub run_migration {
    my $migration = shift;
    my $function = $migration->{status} eq 'down'? 'up' : 'down';

    no strict 'refs';
    #load $migration->{path};

    my $handler = Migrate::Handler::get_handler();
    "$migration->{package}::$function"->($handler);

    my $dbh = Dbh::getDBH();
    $dbh->begin_work;

    my @sql = @{$handler->{sql}};
    say($_) foreach @sql;
    return;
    $dbh->do($_) foreach @sql;

    if ($function eq 'up') {
        $dbh->do("INSERT INTO _migrations (migration_id) VALUES ('$migration->{id}')");
    }
    else {
        $dbh->do("DELETE FROM _migrations WHERE migration_id = '$migration->{id}'");
    }
    print($@->errstr) if $@;

    $dbh->commit if !$@;
}

return 1;
