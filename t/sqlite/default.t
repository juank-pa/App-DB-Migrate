use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;

use Migrate::SQLite::Constraint::Default;

subtest 'new creates a Default constraint' => sub {
    my $def = Migrate::SQLite::Constraint::Default->new(5, { type => 1 });
    isa_ok($def, 'Migrate::SQLite::Constraint::Default');
    isa_ok($def, 'Migrate::Constraint::Default');
    isa_ok($def, 'Migrate::Constraint');
};

subtest 'current_timestamp returns CURRENT_TIMESTAMP' => sub {
    is(Migrate::SQLite::Constraint::Default->current_timestamp, 'CURRENT_TIMESTAMP');
};

done_testing();
