use strict;
use warnings;

use lib 't/lib';

use Test::More;

use App::DB::Migrate::Constraint::Null;

subtest 'new creates a null constraint' => sub {
    my $null = App::DB::Migrate::Constraint::Null->new();
    isa_ok($null, 'App::DB::Migrate::Constraint::Null');
};

subtest 'is SQLizable' => sub {
    my $null = App::DB::Migrate::Constraint::Null->new();
    isa_ok($null, "App::DB::Migrate::SQLizable");
};

subtest 'is_null when no parameters are sent' => sub {
    my $null = App::DB::Migrate::Constraint::Null->new();
    ok($null->is_null);
};

subtest 'is_null when true is sent' => sub {
    my $null = App::DB::Migrate::Constraint::Null->new(1);
    ok($null->is_null);
};

subtest 'is_null is false when false is sent' => sub {
    my $null = App::DB::Migrate::Constraint::Null->new(0);
    ok(!$null->is_null);
};

subtest 'to_sql returns SQL representation on undef null' => sub {
    my $null = App::DB::Migrate::Constraint::Null->new();
    is($null->to_sql, 'NULL');
};

subtest 'to_sql returns SQL representation on null' => sub {
    my $null = App::DB::Migrate::Constraint::Null->new(1);
    is($null->to_sql, 'NULL');
};

subtest 'to_sql returns SQL representation on null' => sub {
    my $null = App::DB::Migrate::Constraint::Null->new(0);
    is($null->to_sql, 'NOT NULL');
};

done_testing();
