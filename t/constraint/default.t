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

my $datatype = Test::MockObject->new()->mock('quote', sub { "<$_[1]>" });

subtest 'Default new' => sub {
    my $def = Migrate::Constraint::Default->new(5, $datatype);
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
    my $def = Migrate::Constraint::Default->new(33, $datatype);
    is($def->value, 33);
};

subtest 'datatype returns the value' => sub {
    my $def = Migrate::Constraint::Default->new('Hello', $datatype);
    is($def->datatype, $datatype);
};

subtest 'to_sql returns SQL representation of default clause' => sub {
    my $def = Migrate::Constraint::Default->new('Hello', $datatype);
    is($def->to_sql, "DEFAULT <Hello>");
};

subtest 'to_sql returns SQL representation of default timestamp' => sub {
    no warnings 'redefine';
    local *Migrate::Constraint::Default::current_timestamp = sub { 'CURRENT_TIMESTAMP' };
    use warnings 'redefine';

    my $def = Migrate::Constraint::Default->new({ timestamp => 1 }, $datatype);
    is($def->to_sql, "DEFAULT CURRENT_TIMESTAMP");
};

subtest 'to_sql returns SQL representation of a NULL default value' => sub {
    my $def = Migrate::Constraint::Default->new();
    is($def->to_sql, "DEFAULT NULL");
};

subtest 'Default stringifies to an SQL representation of default clause' => sub {
    my $def = Migrate::Constraint::Default->new('Hello', $datatype);
    is("$def", "DEFAULT <Hello>");
};

done_testing();
