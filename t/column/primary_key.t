use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockModule;
use Test::Trap;
use Mocks;

use Migrate::Column::PrimaryKey;

get_mock(COL)
    ->set_false('add_constraint');

subtest 'new creates a primary key column' => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table');
    isa_ok($pk, 'Migrate::Column::PrimaryKey');
};

subtest 'new fails if table name not set' => sub {
    trap { Migrate::Column::PrimaryKey->new('') };
    like($trap->die, qr/^Table name needed/);
};

subtest 'new sets the column name to config-based id if not provided' => sub {
    Migrate::Column::PrimaryKey->new('my_table');
    ok_factory_nth(COL, 0, 'id');

    my $config = new Test::MockModule('Migrate::Config');
    $config->mock(id => 'any_id');
    Migrate::Column::PrimaryKey->new('my_table');
    ok_factory_nth(COL, 0, 'any_id');
};

subtest 'new sets the column name to a custom name if provided' => sub {
    Migrate::Column::PrimaryKey->new('my_table', 'my_id_custom');
    ok_factory_nth(COL, 0, 'my_id_custom');
};

subtest 'new sets the column dataype to integer if not provided' => sub {
    Migrate::Column::PrimaryKey->new('my_table');
    ok_factory_nth(COL, 1, 'integer');
};

subtest 'new sets the column dataype to a custom type if provided' => sub {
    Migrate::Column::PrimaryKey->new('my_table', { type => 'whatever_type' });
    ok_factory_nth(COL, 1, 'whatever_type');

    Migrate::Column::PrimaryKey->new('my_table', 'col', { type => 'whatever_type' });
    ok_factory_nth(COL, 1, 'whatever_type');
};

subtest 'new passes options to column' => sub {
    Migrate::Column::PrimaryKey->new('my_table', { any => 'option' });
    ok_factory_nth(COL, 2, { any => 'option' });

    Migrate::Column::PrimaryKey->new('my_table', 'col', { other => 'option' });
    ok_factory_nth(COL, 2, { other => 'option' });
};

subtest 'new adds a primary key constraint' => sub {
    my $pkc;
    get_mock(COL)->mock('add_constraint', sub { $pkc = $_[1] });
    Migrate::Column::PrimaryKey->new('my_table');
    is($pkc, get_mock(PK));
};

subtest 'new passes the table name to the primary key constraint' => sub {
    Migrate::Column::PrimaryKey->new('my_table', { autoincrement => 1 });
    ok_factory_nth(PK, 0, 'my_table');
};

subtest 'new passes the column name to the primary key constraint' => sub {
    Migrate::Column::PrimaryKey->new('my_table', 'my_column_name', { autoincrement => 1 });
    ok_factory_nth(PK, 1, 'my_column_name');
};

subtest 'new sets primary key constraint to autoincrement when integer and bigint' => sub {
    Migrate::Column::PrimaryKey->new('my_table', { autoincrement => 1 });
    ok_factory_nth(PK, 2, { autoincrement => 1 });

    clear_factories();
    get_mock(DATATYPE)->mock('name', sub { 'bigint' });
    Migrate::Column::PrimaryKey->new('my_table', { autoincrement => 1 });
    ok_factory_nth(PK, 2, { autoincrement => 1 });
};

subtest 'new does not set primary key constraint to autoincrement when any other type' => sub {
    Migrate::Column::PrimaryKey->new('my_table', { type => 'string', autoincrement => 1 });
    ok_factory_nth(PK, 2, { });
};

subtest 'new sets a custom name for the primary key constraint' => sub {
    Migrate::Column::PrimaryKey->new('my_table', { name => 'custom_name' });
    ok_factory_nth(PK, 2, { name => 'custom_name' });
};

subtest 'delegates methods to column' => sub {
    my @methods = qw(name options type constraints index to_sql);
    my $pk = Migrate::Column::PrimaryKey->new('my_table', { name => 'custom_name' });

    for my $method (@methods) {
        get_mock(COL)->mock($method, sub { "Called $method" });
        is($pk->$method(), "Called $method", "Method $method was not delegated");
    }
};

subtest 'is SQLizable' => sub {
    my $pk = Migrate::Column::PrimaryKey->new('table');
    isa_ok($pk, "Migrate::SQLizable");
};

subtest 'autoincrements returns the constraint autoincrements', => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table');
    get_mock(PK)->mock('autoincrements', sub { 'ANYTHING' });
    is($pk->autoincrements, 'ANYTHING');
};

subtest 'primary_key_constraint returns the pk constraint', => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table');
    is($pk->primary_key_constraint, get_mock(PK));
};

done_testing();
