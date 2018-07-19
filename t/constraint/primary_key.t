use strict;
use warnings;

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;

use lib 't/lib';
use MockStringifiedObject;
use Migrate::Factory;
use Migrate::Constraint::PrimaryKey;

my $util = Test::MockModule->new('Migrate::Util');
$util->mock('identifier_name', sub { 'schema.'.$_[0] });

subtest 'new creates a primary key' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('table', 'column');
    isa_ok($pk, 'Migrate::Constraint::PrimaryKey');
    isa_ok($pk, 'Migrate::Constraint');
};

subtest 'new is invalid if table is not sent' => sub {
    trap { Migrate::Constraint::PrimaryKey->new() };
    is($trap->die, "Table name needed\n");
};

subtest 'new is invalid if table is not sent' => sub {
    trap { Migrate::Constraint::PrimaryKey->new('users') };
    is($trap->die, "Column name needed\n");
};

subtest 'autoincrements returns the autoincrement option' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'column', { autoincrement => 1 });
    ok($pk->autoincrements);

    $pk = Migrate::Constraint::PrimaryKey->new('users', 'column');
    ok(!$pk->autoincrements);
};

subtest 'table returns the table name' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'column');
    is($pk->table, 'users');
};

subtest 'column returns column name' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'name');
    is($pk->column, 'name');
};

subtest 'name returns a constructed constraint name' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'id');
    is($pk->name, 'schema.pk_users_id');
};

subtest 'name returns a constructed constraint name with overridden column' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'other_column');
    is($pk->name, 'schema.pk_users_other_column');
};

subtest 'name returns a constructed constraint name with overridden name' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'id', { name => 'my_new_pk_name' });
    is($pk->name, 'schema.my_new_pk_name');
};

subtest 'to_sql returns SQL representation of primary key' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'id');
    is($pk->to_sql, 'CONSTRAINT schema.pk_users_id PRIMARY KEY');
};

subtest 'to_sql returns SQL representation of primary key with autoincrement' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'id', { autoincrement => 1 });
    is($pk->to_sql, 'CONSTRAINT schema.pk_users_id PRIMARY KEY AUTOINCREMENT');
};

subtest 'PrimaryKey stringifies as an SQL representation of primary key with autoincrement' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'id', { autoincrement => 1 });
    is("$pk", 'CONSTRAINT schema.pk_users_id PRIMARY KEY AUTOINCREMENT');
};

done_testing();
