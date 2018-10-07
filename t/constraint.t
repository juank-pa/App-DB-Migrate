use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockModule;
use Mocks;

use App::DB::Migrate::Constraint;

subtest 'new creates a foreign key' => sub {
    my $cns = App::DB::Migrate::Constraint->new({ name => 'constraint_name' });
    isa_ok($cns, 'App::DB::Migrate::Constraint');
};

subtest 'is SQLizable' => sub {
    my $cns = App::DB::Migrate::Constraint->new();
    isa_ok($cns, "App::DB::Migrate::SQLizable");
};

subtest 'name returns the constraint name' => sub {
    my $cns = App::DB::Migrate::Constraint->new({ name => 'constraint_name' });
    is($cns->name, 'constraint_name');
};

subtest 'name returns undef when there was no given name' => sub {
    my $cns = App::DB::Migrate::Constraint->new();
    is($cns->name, undef);
};

subtest 'name does not return undef if build_name is implemented' => sub {
    my $cmod = new Test::MockModule('App::DB::Migrate::Constraint');
    $cmod->redefine('build_name' => 'test_built_name');
    my $cns = App::DB::Migrate::Constraint->new();
    is($cns->name, 'test_built_name');
};

subtest 'constraint_sql returns the constraint name SQL when name is provided' => sub {
    my $cns = App::DB::Migrate::Constraint->new({ name => 'constraint_name' });
    is($cns->constraint_sql, 'CONSTRAINT constraint_name');
};

subtest 'constraint_sql returns undef when name is not provided', => sub {
    my $cns = App::DB::Migrate::Constraint->new();
    is($cns->constraint_sql, undef);
};

subtest 'constraint_sql returns the constraint name SQL when build_name is implemented' => sub {
    my $cmod = new Test::MockModule('App::DB::Migrate::Constraint');
    $cmod->redefine('build_name' => 'test_built_name');
    my $cns = App::DB::Migrate::Constraint->new();
    is($cns->constraint_sql, 'CONSTRAINT test_built_name');
};

# redefinable to determine constraint name location
subtest 'add_constraint adds a constraint SQL to the given SQL token array' => sub {
    my $cns = App::DB::Migrate::Constraint->new({ name => 'constraint_name' });
    my @tokens = $cns->add_constraint('SQL tokens');
    is_deeply(\@tokens, ['CONSTRAINT constraint_name', 'SQL tokens']);
};

done_testing();
