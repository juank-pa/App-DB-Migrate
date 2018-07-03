use strict;
use warnings;

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use File::Spec;

use Migrate::Setup;

my $module = new Test::MockModule('Migrate::Setup');
$module->mock(get_dbh => undef);

sub mock_setup {
    my $val = shift;
    my $module = new Test::MockModule('Migrate::Setup');
    $module->mock(is_migration_setup => sub () { $val } );
    return $module;
}

subtest 'execute prints message migration folder exists' => sub {
    my $module = mock_setup(1);

    trap { Migrate::Setup::execute() };

    is($trap->stdout, "Migrations have already been setup.\n");
};

subtest 'execute does not perform migrations if migration folder already exists' => sub {
    my $module = mock_setup(1);
    my $execs;
    $module->mock(create_migrations_folder => sub { $execs++ } );
    $module->mock(create_migrations_table => sub { $execs++ } );

    Migrate::Setup::execute();

    is($execs, undef, 'should not execute migration steps');
};

subtest 'execute creates migration items if they do not already exist' => sub {
    my $module = mock_setup(0);
    my $setup;
    $module->mock(setup => sub { $setup++; () } );

    Migrate::Setup::execute();

    is($setup, 1, 'creates migration folders');
};

subtest 'execute prints the setup results' => sub {
    my $module = mock_setup(0);
    $module->mock(setup => sub { ('File: x', 'Error: y') } );
    my $file = File::Spec->catfile('db','config.pl');

    trap { Migrate::Setup::execute() };

    is($trap->stdout, <<EOF);
Created items:
  File: x
  Error: y

Edit $file with the right DB credentials.
EOF
};

done_testing;
