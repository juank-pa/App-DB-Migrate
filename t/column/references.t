use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::Trap;
use Mocks;

use Migrate::Column::References;

get_mock(COL)
    ->set_false('add_constraint');

subtest 'new creates a reference column' => sub {
    my $pk = Migrate::Column::References->new('my_table', 'column');
    isa_ok($pk, 'Migrate::Column::References');
};

subtest 'new fails is ref_name is not provided' => sub {
    trap { Migrate::Column::References->new('table', '') };
    like($trap->die, qr/^Reference name is needed/);
};

subtest 'new fails is table is not provided' => sub {
    trap { Migrate::Column::References->new('', 'column') };
    like($trap->die, qr/^Table name is needed/);
};

subtest 'new sets an index by default' => sub {
    Migrate::Column::References->new('table', 'my_ref');
    ok_factory_nth(COL, 2, { index => 1 });
};

subtest 'new allows overriding the index' => sub {
    Migrate::Column::References->new('table', 'my_ref', { index => 0 });
    ok_factory_nth(COL, 2, { index => 0 });
};

subtest 'new passes the column name to column' => sub {
    Migrate::Column::References->new('table', 'my_ref');
    ok_factory_nth(COL, 0, 'my_ref_id');
};

subtest 'new overrides the column name' => sub {
    Migrate::Column::References->new('table', 'column', { foreign_key => { column => 'new_col_name' } });
    ok_factory_nth(COL, 0, 'new_col_name');
};

subtest 'new passes integer as the column datatype' => sub {
    Migrate::Column::References->new('table', 'column');
    ok_factory_nth(COL, 1, 'integer');
};

subtest 'new overrides the column datatype' => sub {
    Migrate::Column::References->new('table', 'column', { type => 'anytype' });
    ok_factory_nth(COL, 1, 'anytype');
};

subtest 'new passes options to column' => sub {
    Migrate::Column::References->new('table', 'my_ref', { any => 'options' });
    ok_factory_nth(COL, 2, { index => 1, any => 'options' });
};

subtest 'new does not create a foreign key by default' => sub {
    clear_factories();
    Migrate::Column::References->new('table', 'my_ref', { any => 'options' });
    ok_factory(FK, undef);
};

subtest 'new can create a foreign key from table' => sub {
    Migrate::Column::References->new('my_table', 'my_ref', { foreign_key => 1 });
    ok_factory_nth(FK, 0, 'my_table');
};

subtest 'new can create a foreign key to pruralized ref_name table' => sub {
    Migrate::Column::References->new('table', 'departments', { foreign_key => 1 });
    ok_factory_nth(FK, 1, 'departments');
};

subtest 'new can create a foreign key with overridden to table' => sub {
    Migrate::Column::References->new('table', 'departments', { foreign_key => { to_table => 'new_table' } });
    ok_factory_nth(FK, 1, 'new_table');
};

subtest 'new passes options to foreign key' => sub {
    Migrate::Column::References->new('table', 'departments', { foreign_key => { any => 'options' } });
    ok_factory_nth(FK, 2, { any => 'options' });
};

subtest 'new passes empty options if not hash' => sub {
    Migrate::Column::References->new('table', 'departments', { foreign_key => 1 });
    ok_factory_nth(FK, 2, { });
};

subtest 'new adds foreign_key constraint' => sub {
    my $fk;
    get_mock(COL)->mock('add_constraint', sub { $fk = $_[1] });

    Migrate::Column::References->new('table', 'departments', { foreign_key => 1 });
    is($fk, get_mock(FK));
};

subtest 'delegates methods to column' => sub {
    my @methods = qw(name options type constraints index to_sql);
    my $ref = Migrate::Column::References->new('my_table', 'col');

    for my $method (@methods) {
        get_mock(COL)->mock($method, sub { "Called $method" });
        is($ref->$method(), "Called $method", "Method $method was not delegated");
    }
};

subtest 'is SQLizable' => sub {
    my $ref = Migrate::Column::References->new('table', 'col');
    isa_ok($ref, "Migrate::SQLizable");
};

subtest 'foreign_key_constraint returns the foreign key', => sub {
    my $ref = Migrate::Column::References->new('table', 'col', { foreign_key => 1 });
    is($ref->foreign_key_constraint, get_mock(FK));
};

subtest 'foreign_key_constraint returns undef if no foreign key', => sub {
    my $ref = Migrate::Column::References->new('table', 'col');
    ok(!$ref->foreign_key_constraint);
};

subtest 'table returns the table name', => sub {
    my $ref = Migrate::Column::References->new('table_name', 'col');
    is($ref->table, 'table_name');
};

subtest 'raw_name returns the non-processed ref_name', => sub {
    my $ref = Migrate::Column::References->new('table_name', 'pre_col');
    is($ref->raw_name, 'pre_col');
};

done_testing();
