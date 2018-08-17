use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;

use Migrate::SQLite::Table;

my $constraint = new Test::MockModule('Migrate::Config');
$constraint->redefine('config', { dsn => 'dbi:SQLite:sample' });

subtest 'new creates a SQLite Identifier' => sub {
    my $def = Migrate::SQLite::Table->new('name');
    isa_ok($def, 'Migrate::SQLite::Table');
    isa_ok($def, 'Migrate::Table');
};

subtest 'temporary returns TEMPORARY' => sub {
    is(Migrate::SQLite::Table->temporary, 'TEMPORARY');
};

done_testing();
