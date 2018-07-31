use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use File::Path qw(remove_tree make_path);
use File::Spec;
use Scalar::Util qw(isweak);

use Migrate::Constraint::Default;

my $datatype = Test::MockObject->new()
    ->mock('quote', sub { "<$_[1]>" })
    ->mock('name', sub { 'string' });

no warnings 'redefine';
local *Migrate::Util::identifier_name = sub { qq{"$_[0]"} if $_[0] };
use warnings;

subtest 'Default new' => sub {
    my $def = Migrate::Constraint::Default->new(5, { type => $datatype });
    isa_ok($def, 'Migrate::Constraint::Default');
};

subtest 'Default new fails if no datatype is given' => sub {
    trap { Migrate::Constraint::Default->new(5) };
    is($trap->die, "Datatype is needed\n");
};

subtest 'Default new does not fail if value is undef' => sub {
    my $def = Migrate::Constraint::Default->new();
    isa_ok($def, 'Migrate::Constraint::Default');
};

subtest 'Default new does not fail if default is timestamp' => sub {
    my $def = Migrate::Constraint::Default->new({ timestamp => 1 });
    isa_ok($def, 'Migrate::Constraint::Default');
};

subtest 'datatype returns the datatype' => sub {
    my $def = Migrate::Constraint::Default->new(33, { type => $datatype });
    is($def->value, 33);
};

subtest 'datatype returns the value' => sub {
    my $def = Migrate::Constraint::Default->new('Hello', { type => $datatype });
    is_deeply($def->datatype, $datatype);
};

subtest 'to_sql returns SQL representation of default clause' => sub {
    my $def = Migrate::Constraint::Default->new('Hello', { type => $datatype });
    is($def->to_sql, "DEFAULT <Hello>");
};

subtest 'to_sql returns SQL representation of default timestamp' => sub {
    no warnings 'redefine';
    local *Migrate::Constraint::Default::current_timestamp = sub { 'CURRENT_TIMESTAMP' };
    use warnings 'redefine';

    my $def = Migrate::Constraint::Default->new({ timestamp => 1 }, { type => $datatype });
    is($def->to_sql, "DEFAULT CURRENT_TIMESTAMP");
};

subtest 'to_sql returns SQL representation of a NULL default value' => sub {
    my $def = Migrate::Constraint::Default->new();
    is($def->to_sql, "DEFAULT NULL");
};

subtest 'to_sql returns SQL representation of a BOOLEAN default value' => sub {
    my $bool_dt = Test::MockObject->new()->mock('name', sub { 'boolean' });

    my $def = Migrate::Constraint::Default->new(1, { type => $bool_dt });
    is($def->to_sql, "DEFAULT TRUE");

    $def = Migrate::Constraint::Default->new(0, { type => $bool_dt });
    is($def->to_sql, "DEFAULT FALSE");
};

subtest 'Default stringifies to an SQL representation of default clause' => sub {
    my $def = Migrate::Constraint::Default->new('Hello', { type => $datatype });
    is("$def", "DEFAULT <Hello>");
};

subtest 'Default stringifies to an SQL representation of a consatrained default clause' => sub {
    my $def = Migrate::Constraint::Default->new('Hello', { type => $datatype, name => 'default_constraint' });
    is("$def", 'CONSTRAINT "default_constraint" DEFAULT <Hello>');
};

done_testing();
