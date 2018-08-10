use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::Trap;
use Mocks;

use Migrate::Constraint::PrimaryKey;

subtest 'new creates a primary key' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('table', 'column');
    isa_ok($pk, 'Migrate::Constraint::PrimaryKey');
    isa_ok($pk, 'Migrate::Constraint');
};

subtest 'new is invalid if table is not sent' => sub {
    trap { Migrate::Constraint::PrimaryKey->new() };
    like($trap->die, qr/^Table name needed/);
};

subtest 'new is invalid if table is not sent' => sub {
    trap { Migrate::Constraint::PrimaryKey->new('users') };
    like($trap->die, qr/^Column name needed/);
};

subtest 'is SQLizable' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'name');
    isa_ok($pk, "Migrate::SQLizable");
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
    is($pk->name, 'pk_users_id');
};

subtest 'name returns a constructed constraint name with custom column' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'other_column');
    is($pk->name, 'pk_users_other_column');
};

subtest 'name returns a constructed constraint name with overridden name' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'id', { name => 'my_new_pk_name' });
    is($pk->name, 'my_new_pk_name');
};

subtest 'to_sql returns SQL representation of primary key' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'id');
    is($pk->to_sql, 'CONSTRAINT pk_users_id PRIMARY KEY');
};

subtest 'to_sql returns SQL representation of primary key with autoincrement' => sub {
    my $pk = Migrate::Constraint::PrimaryKey->new('users', 'id', { autoincrement => 1 });
    is($pk->to_sql, 'CONSTRAINT pk_users_id PRIMARY KEY AUTOINCREMENT');
};

done_testing();
