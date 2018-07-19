use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use MockStringifiedObject;

use Migrate::Constraint::Null;

subtest 'Null new creates a null constraint' => sub {
    my $null = Migrate::Constraint::Null->new();
    isa_ok($null, 'Migrate::Constraint::Null');
};

subtest 'is_null when no parameters are sent' => sub {
    my $null = Migrate::Constraint::Null->new();
    ok($null->is_null);
};

subtest 'is_null when true is sent' => sub {
    my $null = Migrate::Constraint::Null->new(1);
    ok($null->is_null);
};

subtest 'is_null is false when false is sent' => sub {
    my $null = Migrate::Constraint::Null->new(0);
    ok(!$null->is_null);
};

subtest 'to_sql returns SQL representation on undef null' => sub {
    my $null = Migrate::Constraint::Null->new();
    is($null->to_sql, 'NULL');
};

subtest 'to_sql returns SQL representation on null' => sub {
    my $null = Migrate::Constraint::Null->new(1);
    is($null->to_sql, 'NULL');
};

subtest 'to_sql returns SQL representation on null' => sub {
    my $null = Migrate::Constraint::Null->new(0);
    is($null->to_sql, 'NOT NULL');
};

subtest 'Null stringifies SQL representation on null' => sub {
    my $null = Migrate::Constraint::Null->new(0);
    is("$null", 'NOT NULL');
};

done_testing();
