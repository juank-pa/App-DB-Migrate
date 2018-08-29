use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;

use App::DB::Migrate::SQLite::Table;

my $constraint = new Test::MockModule('App::DB::Migrate::Config');
$constraint->redefine('config', { dsn => 'dbi:SQLite:sample' });

subtest 'new creates a SQLite Identifier' => sub {
    my $def = App::DB::Migrate::SQLite::Table->new('name');
    isa_ok($def, 'App::DB::Migrate::SQLite::Table');
    isa_ok($def, 'App::DB::Migrate::Table');
};

subtest 'temporary returns TEMPORARY' => sub {
    is(App::DB::Migrate::SQLite::Table->temporary, 'TEMPORARY');
};

done_testing();
