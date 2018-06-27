package Migrate::Setup;

use strict;
use warnings;
use feature 'say';

use File::Path qw(make_path);
use Dbh;

sub execute
{
    if (-e './db/migrations') {
        say('Migrations have already been setup.');
        return;
    }

    createMigrationsFolder();
    createMigrationsTable(Dbh->getDBH());
}

sub createMigrationsFolder
{
    eval { make_path('./db'); make_path("./db/migrations") };
    if ($@) {
        say("Could not create migrations directory!");
    }
}

sub createMigrationsTable
{
    my $dbh = shift;
    Dbh::doSQL($_, {}, $dbh) foreach Migrate::Handler->create_migrations_table_query;
}

sub isSetup
{
    return -e './db/migrations';
}

return 1;
