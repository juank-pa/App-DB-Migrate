use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;

use Migrate::SQLite::Identifier;

subtest 'new creates a SQLite Identifier' => sub {
    my $def = Migrate::SQLite::Identifier->new('name');
    isa_ok($def, 'Migrate::SQLite::Identifier');
    isa_ok($def, 'Migrate::Identifier');
};

subtest 'new ignores the quialified parameter so SQLite ids are always unqualified' => sub {
    my $def = Migrate::SQLite::Identifier->new('name', 1);
    ok(!$def->is_qualified);
};

done_testing();
