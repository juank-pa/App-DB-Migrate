package Migrate::Run;

use strict;
use warnings;
use feature 'say';

use Migrate::Dbh qw(get_dbh);
use Migrate::Factory qw(handler class);
use Data::Dumper;
use List::Util qw(min);

sub run {
    my $options = shift;
    Migrate::Setup::setup_migrations_table();
    _run_migrations('down', -1, $options->{dry})
}

sub rollback {
    my $options = shift;
    my $steps = $options->{steps} || 1;
    Migrate::Setup::setup_migrations_table();
    _run_migrations('up', $steps, $options->{dry})
}

sub _run_migrations {
    my $filter = shift;
    my $steps = shift;
    my $dry = shift;
    my @migrations = _filtered_migrations($filter, $steps);
    say('No more migrations to '.($steps == -1? 'run' : 'rollback')) && exit unless @migrations;
    say("Dry run:\n") if $dry;
    _run_migration($_, $dry) foreach @migrations;
}

sub _filtered_migrations {
    my $filter = shift;
    my $steps = shift // 1;

    my @migrations = (grep { $_->{status} eq $filter } Migrate::Status::get_migrations());
    $steps = scalar(@migrations) if $steps < 0;
    @migrations = reverse @migrations if $filter eq 'up';

    return () unless scalar @migrations;
    return @migrations[0 .. min($steps - 1, $#migrations)];
}

sub _run_migration {
    my ($migration, $dry) = @_;
    my $function = $migration->{status} eq 'down'? 'up' : 'down';
    my $handler = handler($dry, *STDOUT);

    _load_migration($migration->{path}, $migration->{package});

    my $dbh = get_dbh();
    $dbh->begin_work;

    eval {
        _run_migration_function($migration->{package}, $function, $handler);
        _record_migration($function, $migration->{id}, $dbh) unless $dry;
    };

    return $dbh->commit unless $@;

    $dbh->rollback;
    die($@);
}

sub _load_migration {
    my ($path, $package) = @_;
    open(my $fh, '<', $path);
    my $contents = do{ local $/; <$fh> };
    eval qq{package $package; $contents};
}

sub _run_migration_function {
    my ($package, $function, $handler) = @_;
    my $qualified_function = "${package}::${function}";

    say('-' x (length($qualified_function) + 8));
    say("Running $qualified_function");

    no strict 'refs';
    $qualified_function->($handler);
    use strict;
    $handler->flush();
}

sub _record_migration {
    my ($function, $id, $dbh) = @_;
    my $sql = $function eq 'up'
        ? class('migrations')->insert_migration_sql
        : class('migrations')->delete_migration_sql;
    $dbh->prepare($sql)->execute($id) or die("Error recording migration data ($function)");
}

return 1;
