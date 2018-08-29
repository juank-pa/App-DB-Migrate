use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;

use App::DB::Migrate::Constraint::Default;

my $datatype = Test::MockObject->new()
    ->mock('quote', sub { "<$_[1]>" })
    ->mock('name', sub { 'string' });

subtest 'new creates a Default constraint' => sub {
    my $def = App::DB::Migrate::Constraint::Default->new(5, { type => $datatype });
    isa_ok($def, 'App::DB::Migrate::Constraint::Default');
    isa_ok($def, 'App::DB::Migrate::Constraint');
};

subtest 'new fails if no datatype is given' => sub {
    trap { App::DB::Migrate::Constraint::Default->new(5) };
    like($trap->die, qr/^Datatype is needed/);
};

subtest 'new does not fail if value is undef' => sub {
    my $def = App::DB::Migrate::Constraint::Default->new();
    isa_ok($def, 'App::DB::Migrate::Constraint::Default');
};

subtest 'new does not fail if default is timestamp' => sub {
    my $def = App::DB::Migrate::Constraint::Default->new({ timestamp => 1 });
    isa_ok($def, 'App::DB::Migrate::Constraint::Default');
};

subtest 'is SQLizable' => sub {
    my $def = App::DB::Migrate::Constraint::Default->new();
    isa_ok($def, "App::DB::Migrate::SQLizable");
};

subtest 'value returns the constraint value' => sub {
    my $def = App::DB::Migrate::Constraint::Default->new(33, { type => $datatype });
    is($def->value, 33);
};

subtest 'type returns the datatype' => sub {
    my $def = App::DB::Migrate::Constraint::Default->new('Hello', { type => $datatype });
    is_deeply($def->type, $datatype);
};

subtest 'to_sql returns SQL representation of default clause' => sub {
    my $def = App::DB::Migrate::Constraint::Default->new('Hello', { type => $datatype });
    is($def->to_sql, "DEFAULT <Hello>");
};

subtest 'to_sql returns SQL representation of default timestamp' => sub {
    my $default = new Test::MockModule('App::DB::Migrate::Constraint::Default');
    $default->mock('current_timestamp', 'CURRENT_TIMESTAMP');

    my $def = App::DB::Migrate::Constraint::Default->new({ timestamp => 1 }, { type => $datatype });
    is($def->to_sql, "DEFAULT CURRENT_TIMESTAMP");
};

subtest 'to_sql returns SQL representation of a NULL default value' => sub {
    my $def = App::DB::Migrate::Constraint::Default->new();
    is($def->to_sql, "DEFAULT NULL");
};

subtest 'to_sql returns SQL representation of a BOOLEAN true default value' => sub {
    my $bool_dt = Test::MockObject->new()->mock('name', sub { 'boolean' });

    my $def = App::DB::Migrate::Constraint::Default->new(1, { type => $bool_dt });
    is($def->to_sql, "DEFAULT TRUE");
};

subtest 'to_sql returns SQL representation of a BOOLEAN true default value' => sub {
    my $bool_dt = Test::MockObject->new()->mock('name', sub { 'boolean' });

    my $def = App::DB::Migrate::Constraint::Default->new(0, { type => $bool_dt });
    is($def->to_sql, "DEFAULT FALSE");
};

done_testing();
