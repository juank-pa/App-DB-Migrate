use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Trap;

use App::DB::Migrate::SQLite::Editor::Column;

my $constraint = new Test::MockModule('App::DB::Migrate::Config');
$constraint->mock('config', { dsn => 'dbi:SQLite:sample' });

subtest 'new creates a new editor column object' => sub {
    isa_ok(App::DB::Migrate::SQLite::Editor::Column->new('any'), 'App::DB::Migrate::SQLite::Editor::Column');
};

subtest 'new fails if column name is undef' => sub {
    trap { App::DB::Migrate::SQLite::Editor::Column->new() };
    like($trap->die, qr/^Column name needed/);
};

subtest 'is SQLizable' => sub {
    my $cns = App::DB::Migrate::SQLite::Editor::Column->new('my_name', 'null');
    isa_ok($cns, 'App::DB::Migrate::SQLizable');
};

subtest 'name returns the column name' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('col1');
    is($col->name, 'col1');
};

subtest 'rename changes the column name' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('col1');
    $col->rename('new_name');
    is($col->name, 'new_name');
};

subtest 'rename fails is new name is undef' => sub {
    trap { App::DB::Migrate::SQLite::Editor::Column->new('name')->rename() };
    like($trap->die, qr/^Column name needed/);
};

subtest 'type returns the column type' => sub {
    my $dt = App::DB::Migrate::SQLite::Editor::Datatype->new('INT');
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', $dt);
    is($col->type, $dt);
    is($col->type->native_name, 'INT');
};

subtest 'type returns an undefined datatype is none is given' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name');
    is($col->type->native_name, '');
};

subtest 'constraints returns the list of constraints' => sub {
    my $c1 = App::DB::Migrate::SQLite::Editor::Constraint->new(undef, 'NOT NULL');
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $c1);
    is($col->constraints->[0], 'ANY');
    is($col->constraints->[1], $c1);
};

subtest 'is_null returns true if there is not any NOT NULL constraint' => sub {
    my $df = App::DB::Migrate::SQLite::Editor::Constraint->new(undef, 'DEFAULT', 5);
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $df);
    ok($col->is_null);
};

subtest 'is_null returns false if there is a NOT NULL constraint' => sub {
    my $nl = App::DB::Migrate::SQLite::Editor::Constraint->new(undef, 'not null');
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $nl);
    ok(!$col->is_null);
};

subtest 'change_null does nothing if status is equal to parameter' => sub {
    my $nl = App::DB::Migrate::SQLite::Editor::Constraint->new(undef, 'not null');
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $nl);
    my $res = $col->change_null(0);
    ok(!$res);
    is(scalar @{ $col->constraints }, 2);
    is($col->constraints->[1], $nl);

    $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', 'THING');
    $res = $col->change_null(1);
    ok(!$res);
    is_deeply($col->constraints, ['ANY', 'THING']);
};

subtest 'change_null removes a not null if true is sent' => sub {
    my $nl = App::DB::Migrate::SQLite::Editor::Constraint->new(undef, 'not null');
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $nl, 'THING');
    my $res = $col->change_null(1);
    ok($res);
    is(scalar @{ $col->constraints }, 2);
    is_deeply($col->constraints, ['ANY', 'THING']);
};

subtest 'change_null adds a not null constraint if false is sent' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', 'THING');
    my $res = $col->change_null(0);
    ok($res);
    is(scalar @{ $col->constraints }, 3);
    is_deeply($col->constraints, ['ANY', 'THING', 'NOT NULL']);
    isa_ok($col->constraints->[2], 'App::DB::Migrate::SQLite::Editor::Constraint');
    is($col->constraints->[2]->type, 'NOT NULL');
};

subtest 'change_null removes any previous null and adds a not null constraint if false is sent' => sub {
    my $nl = App::DB::Migrate::SQLite::Editor::Constraint->new(undef, 'null');
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $nl, 'THING');
    my $res = $col->change_null(0);
    ok($res);
    is(scalar @{ $col->constraints }, 3);
    is_deeply($col->constraints, ['ANY', 'THING', 'NOT NULL']);
    isa_ok($col->constraints->[2], 'App::DB::Migrate::SQLite::Editor::Constraint');
    is($col->constraints->[2]->type, 'NOT NULL');
};

subtest 'default_constraint returns the default constraint if it exists' => sub {
    my $df = App::DB::Migrate::SQLite::Editor::Constraint->new(undef, 'default', 5);
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $df, 'THING');
    isa_ok($col->default_constraint, 'App::DB::Migrate::SQLite::Editor::Constraint');
    is($col->default_constraint->type, 'DEFAULT');
    is($col->default_constraint, $col->constraints->[1]);
};

subtest 'default_constraint returns undef if a default constraint does not exist' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', 'THING');
    my $res = $col->default_constraint;
    ok(!$res);
};

subtest 'change_default does nothing if param is null and column does not have default' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', 'THING');
    my $res = $col->change_default(undef);
    ok(!$res);
    is_deeply($col->constraints, ['ANY', 'THING']);
};

subtest 'change_default removes a previous default constraint if param is undef' => sub {
    my $df = App::DB::Migrate::SQLite::Editor::Constraint->new(undef, 'default', 5);
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $df, 'THING');
    my $res = $col->change_default(undef);
    ok($res);
    is_deeply($col->constraints, ['ANY', 'THING']);
};

subtest 'change_default adds a default if did not exist previosuly' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', 'THING');
    my $res = $col->change_default("I'm JK");
    ok($res);
    is_deeply($col->constraints, ['ANY', 'THING', "DEFAULT 'I''m JK'"]);
    isa_ok($col->constraints->[2], 'App::DB::Migrate::SQLite::Editor::Constraint');
    is($col->constraints->[2]->type, 'DEFAULT');
};

subtest 'change_default updates a default (value only) if it already exists' => sub {
    my $df = App::DB::Migrate::SQLite::Editor::Constraint->new('any_name', 'default', "'val'");
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $df, 'THING');
    is($col->constraints->[1], qq{CONSTRAINT "any_name" DEFAULT 'val'});
    my $res = $col->change_default("New J'K");

    ok($res);
    is_deeply($col->constraints, ['ANY', qq{CONSTRAINT "any_name" DEFAULT 'New J''K'}, 'THING']);
    isa_ok($col->constraints->[1], 'App::DB::Migrate::SQLite::Editor::Constraint');
    is($col->constraints->[1]->type, 'DEFAULT');
    is($col->constraints->[1]->predicate->[0], "'New J''K'");
};

subtest 'change_default updates a default (value only) if it already exists' => sub {
    my $df = App::DB::Migrate::SQLite::Editor::Constraint->new('any_name', 'default', "'val'");
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $df, 'THING');
    is($col->constraints->[1], qq{CONSTRAINT "any_name" DEFAULT 'val'});
    my $res = $col->change_default("New J'K");

    ok($res);
    is_deeply($col->constraints, ['ANY', qq{CONSTRAINT "any_name" DEFAULT 'New J''K'}, 'THING']);
    isa_ok($col->constraints->[1], 'App::DB::Migrate::SQLite::Editor::Constraint');
    is($col->constraints->[1]->type, 'DEFAULT');
    is($col->constraints->[1]->predicate->[0], "'New J''K'");
};

subtest 'change_default does not quote new value depending on dataype' => sub {
    my $df = App::DB::Migrate::SQLite::Editor::Constraint->new('any_name', 'default', "'val'");
    my $dt = App::DB::Migrate::SQLite::Editor::Datatype->new('INT');
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', $dt, 'ANY', $df, 'THING');
    my $res = $col->change_default(5);

    ok($res);
    is_deeply($col->constraints, ['ANY', 'CONSTRAINT "any_name" DEFAULT 5', 'THING']);
    is($col->constraints->[1]->predicate->[0], '5');
};

subtest 'foreign_key_constraint returns the foreign key constrain if it exists' => sub {
    my $fk = App::DB::Migrate::SQLite::Editor::Constraint->new(undef, 'REFERENCES', 'table');
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $fk, 'THING');
    isa_ok($col->foreign_key_constraint, 'App::DB::Migrate::SQLite::Editor::Constraint');
    is($col->foreign_key_constraint->type, 'REFERENCES');
    is($col->foreign_key_constraint, $col->constraints->[1]);
};

subtest 'add_foreign_key does nothing if a foreign key exists' => sub {
    my $fk = App::DB::Migrate::SQLite::Editor::Constraint->new('any', 'REFERENCES', 'table');
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $fk, 'THING');
    my $res = $col->add_foreign_key('REFERENCES other (c1)');

    ok(!$res);
    is_deeply($col->constraints, ['ANY', 'CONSTRAINT "any" REFERENCES table', 'THING']);
};

subtest 'add_foreign_key adds a foreign key if it does not exist' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', 'THING');
    my $res = $col->add_foreign_key('REFERENCES other (c1)');

    ok($res);
    is_deeply($col->constraints, ['ANY', 'THING', 'REFERENCES other (c1)']);
};

subtest 'add_foreign_key can receive anything that serializes as a constraint' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', 'THING');
    my $fk = App::DB::Migrate::SQLite::Editor::Constraint->new('any', 'REFERENCES', 'table');
    my $res = $col->add_foreign_key($fk);

    ok($res);
    is_deeply($col->constraints, ['ANY', 'THING', 'CONSTRAINT "any" REFERENCES table']);
    isa_ok($col->constraints->[2], 'App::DB::Migrate::SQLite::Editor::Constraint');
    is($col->constraints->[2]->type, 'REFERENCES');

    use App::DB::Migrate::Constraint::ForeignKey;

    $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', 'THING');
    $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments');
    $res = $col->add_foreign_key($fk);

    ok($res);
    is_deeply($col->constraints, ['ANY', 'THING', 'CONSTRAINT "fk_users_department_id" REFERENCES "departments" ("id")']);
    isa_ok($col->constraints->[2], 'App::DB::Migrate::SQLite::Editor::Constraint');
    is($col->constraints->[2]->type, 'REFERENCES');
};

subtest 'add_foreign_key fails if string cannot be parsed as a foreign_key' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', 'THING');
    trap { $col->add_foreign_key('ANYTHING') };
    like($trap->die, qr/^Invalid foreign key/);

    use App::DB::Migrate::Constraint::Default;
    use App::DB::Migrate::SQLite::Datatype;

    $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', 'THING');
    my $dt = App::DB::Migrate::SQLite::Datatype->new('integer');
    my $fk = App::DB::Migrate::Constraint::Default->new(5, { type => $dt });
    trap { $col->add_foreign_key($fk) };
    like($trap->die, qr/^Invalid foreign key/);
};

subtest 'remove_foreign_key removes an existing foreign_key' => sub {
    my $fk = App::DB::Migrate::SQLite::Editor::Constraint->new('any', 'REFERENCES', 'table');
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $fk, 'THING');
    my $res = $col->remove_foreign_key();

    ok($res);
    is_deeply($col->constraints, ['ANY', 'THING']);
};

subtest 'has_constraint_named returns true if a constraint with a given name exists' => sub {
    my $fk = App::DB::Migrate::SQLite::Editor::Constraint->new('anything', 'REFERENCES', 'table');
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', $fk, 'THING');
    my $res = $col->has_constraint_named('anything');
    ok($res);
};

subtest 'has_constraint_named returns false if a constraint with a given name does not exists' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('name', undef, 'ANY', 'THING');
    my $res = $col->has_constraint_named('anything');
    ok(!$res);
};

subtest 'to_sql returns a SQL representation of the column without datatype' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('col"name', undef);
    is($col->to_sql, '"col""name"');
};

subtest 'to_sql returns a SQL representation of the column with datatype' => sub {
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('col"name', 'DOUBLE');
    is($col->to_sql, '"col""name" DOUBLE');
};

subtest 'to_sql returns a SQL representation of the column with constraints' => sub {
    my $fk = App::DB::Migrate::SQLite::Editor::Constraint->new('any', 'references', 'table', '(c1)');
    my $col = App::DB::Migrate::SQLite::Editor::Column->new('col_name', 'VARCHAR', 'ANY', $fk, 'thing');
    is($col->to_sql, '"col_name" VARCHAR ANY CONSTRAINT "any" REFERENCES table (c1) thing');
};

done_testing();
