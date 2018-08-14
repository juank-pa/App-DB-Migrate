use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockModule;
use Test::Trap;

use Migrate::SQLite::Editor::Constraint;

my $constraint = new Test::MockModule('Migrate::Config');
$constraint->mock('config', { dsn => 'dbi:SQLite:sample' });

subtest 'new creates a new constraint' => sub {
    my $cns = Migrate::SQLite::Editor::Constraint->new(undef, 'not null');
    isa_ok($cns, 'Migrate::SQLite::Editor::Constraint');
};

subtest 'new fails if type is undef' => sub {
    trap { Migrate::SQLite::Editor::Constraint->new() };
    like($trap->die, qr/^Constraint type is needed/);
};

subtest 'is SQLizable' => sub {
    my $cns = Migrate::SQLite::Editor::Constraint->new('my_name', 'null');
    isa_ok($cns, 'Migrate::SQLizable');
};

subtest 'name returns the constraint name' => sub {
    my $cns = Migrate::SQLite::Editor::Constraint->new('my_name', 'null');
    is($cns->name, 'my_name');
};

subtest 'type returns the upper cased type' => sub {
    my $cns = Migrate::SQLite::Editor::Constraint->new('my_name', 'null');
    is($cns->type, 'NULL');
};

subtest 'predicate returns the predicate' => sub {
    my @pred = ('the', 'predicate');
    my $cns = Migrate::SQLite::Editor::Constraint->new(undef, 'null', @pred);
    is_deeply($cns->predicate, \@pred);
};

subtest 'set_predicate changes the predicate' => sub {
    my $cns = Migrate::SQLite::Editor::Constraint->new(undef, 'null', 'the', 'predicate');
    $cns->set_predicate('anything', 'else');
    $cns->to_sql;
    is_deeply($cns->predicate, ['anything', 'else']);
};

subtest 'to_sql returns an SQL representation' => sub {
    my $cns = Migrate::SQLite::Editor::Constraint->new(undef, 'null');
    is($cns->to_sql, 'NULL');
};

subtest 'to_sql returns an SQL representation of a named constraint' => sub {
    my $cns = Migrate::SQLite::Editor::Constraint->new('my"name', 'not null');
    is($cns->to_sql, 'CONSTRAINT "my""name" NOT NULL');
};

subtest 'to_sql returns an SQL representation with a predicate' => sub {
    my $cns = Migrate::SQLite::Editor::Constraint->new(undef, 'references', '"table"', '(c1)');
    is($cns->to_sql, 'REFERENCES "table" (c1)');
};

subtest 'to_sql returns an SQL representation with a name and a predicate' => sub {
    my $cns = Migrate::SQLite::Editor::Constraint->new('cname', 'references', '"table"', '(c1)');
    is($cns->to_sql, 'CONSTRAINT "cname" REFERENCES "table" (c1)');
};

done_testing();
