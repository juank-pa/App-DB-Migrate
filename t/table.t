use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use MockStringifiedObject;

use Migrate::Table;

my $datatype = Test::MockObject->new()
    ->mock('is_valid_datatype', sub { shift; grep /string|integer/, @_ });

my $mocks = {
    datatype => $datatype,
    column => MockStringifiedObject->new('<COLUMN>'),
    'Column::Timestamp' => MockStringifiedObject->new('<TIMESTAMP>'),
    'Column::References' => MockStringifiedObject->new('<REFERENCE>'),
    'Column::PrimaryKey' => MockStringifiedObject->new('<PK_COLUMN>')->mock('add_constraint', sub { $_[0]->{constraint} = $_[1] })
};

our $args = {};
our $fail = 0;
our $agregate = 0;

no warnings 'redefine';
local *Migrate::Table::class = sub { $mocks->{$_[0]} };
local *Migrate::Table::create = sub {
    die("Column failed\n") if $fail;

    my ($type, @largs) = @_;
    if ($agregate) { push(@{$args->{$type}}, @largs) }
    else { $args->{$type} = \@largs }
    return $mocks->{$type};
};
use warnings 'redefine';

my $util = Test::MockModule->new('Migrate::Util');
$util->mock('identifier_name', sub { 'schema.'.$_[0] });

subtest 'Table new' => sub {
    my $th = Migrate::Table->new('my_table');
    isa_ok($th, 'Migrate::Table');
};

subtest 'Table new as a sub class' => sub {
    @TestClass::ISA = qw{Migrate::Table};
    my $th = TestClass->new('my_table');
    isa_ok($th, 'TestClass');
};

subtest 'Table new dies if no table name is provided' => sub {
    trap { Migrate::Table->new('') };
    is($trap->die, "Table name is needed\n");
};

subtest 'Table new creates a table with a primary key' => sub {
    $args->{'Column::PrimaryKey'} = undef;
    my $th = Migrate::Table->new('my_table');
    is(scalar(@{$th->columns}), 1);
    is($th->columns->[0], $mocks->{'Column::PrimaryKey'});
    is_deeply($args->{'Column::PrimaryKey'}, ['my_table', { column => undef, type => undef, autoincrement => 1 }]);
};

subtest 'Table new creates a table with a primary key and custom column' => sub {
    $args->{'Column::PrimaryKey'} = undef;
    my $th = Migrate::Table->new('my_table', { primary_key => 'my_id' });
    is(scalar(@{$th->columns}), 1);
    is($th->columns->[0], $mocks->{'Column::PrimaryKey'});
    is_deeply($args->{'Column::PrimaryKey'}, ['my_table', { column => 'my_id', type => undef, autoincrement => 1 }]);
};

subtest 'Table new creates a table with a primary key and custom datatype' => sub {
    $args->{'Column::PrimaryKey'} = undef;
    my $th = Migrate::Table->new('my_table', { id => 'string' });
    is(scalar(@{$th->columns}), 1);
    is($th->columns->[0], $mocks->{'Column::PrimaryKey'});
    is_deeply($args->{'Column::PrimaryKey'}, ['my_table', { column => undef, type => 'string', autoincrement => 1 }]);
};

subtest 'Table new creates a table without a primary key' => sub {
    $args->{'Column::PrimaryKey'} = undef;
    my $th = Migrate::Table->new('my_table', { id => 0 });
    is(scalar(@{$th->columns}), 0);
    is($args->{'Column::PrimaryKey'}, undef);
};

subtest 'Table->can reports true for generates datatype methods' => sub {
    my $th = Migrate::Table->new('my_table');
    can_ok($th, 'string');
};

subtest 'Table generates methods for handler valid datatypes' => sub {
    my $module = new Test::MockModule('Migrate::Table');
    my @args;
    $module->mock(column => sub { @args = @_ } );

    foreach (qw{string integer}) {
        my $th = Migrate::Table->new('my_table');
        $th->$_('field_name', { opts => 'values' });
        is_deeply(\@args, [$th, 'field_name', $_, { opts => 'values' }]);
    }
};

subtest 'Table does not generate methods if datatype is not valid in handler' => sub {
    my $th = Migrate::Table->new('my_table');
    trap { $th->other('field_name', { opts => 'values' }) };
    is($trap->die, "Invalid function: other\n");
};

subtest 'name returns the table name' => sub {
    my $th = Migrate::Table->new('my_table', { id => 0 });
    is($th->name, 'my_table');
};

subtest 'type methods support many column names without options' => sub {
    my $th = Migrate::Table->new('my_table');
    my $col_count = scalar @{ $th->columns };
    local ($args, $agregate) = ({}, 1);

    $th->string('first_name', 'last_name');

    is(scalar @{ $th->columns }, $col_count + 2);
    is_deeply($args->{column}, ['first_name', 'string', undef,
                                'last_name', 'string', undef]);
};

subtest 'type methods support many column names with options' => sub {
    my $th = Migrate::Table->new('my_table');
    my $col_count = scalar @{ $th->columns };
    my $options = { any => 'Hello', null => 0 };
    local ($args, $agregate) = ({}, 1);

    $th->integer('age', 'count', $options);

    is(scalar @{ $th->columns }, $col_count + 2);
    is_deeply($args->{column}, ['age', 'integer', $options,
                                'count', 'integer', $options]);
};

subtest 'column creates a column receiving a name and a datatype' => sub {
    my $th = Migrate::Table->new('my_table', { id => 0 });
    my $col_count = scalar @{ $th->columns };
    my $options = {};
    $th->column('my_col', 'integer', $options);

    is(scalar @{ $th->columns }, $col_count + 1);
    is_deeply($th->columns->[-1], $mocks->{column});
    is_deeply($args->{column}, ['my_col', 'integer', $options]);
};

subtest 'column dies if column fails' => sub {
    local $fail = 1;
    my $th = Migrate::Table->new('my_table', { id => 0 });
    trap { $th->column('anything', 'string') };
    is($trap->die, "Column failed\n");
};

subtest 'timestamps creates timestamps columns' => sub {
    my $th = Migrate::Table->new('my_table');
    my $col_count = scalar @{ $th->columns };
    my $options = { any => 'Hello', null => 0 };

    local ($args, $agregate) = ({}, 1);
    $th->timestamps($options);

    is(scalar @{ $th->columns }, $col_count + 2);
    is_deeply($th->columns->[-1], $mocks->{'Column::Timestamp'});
    is_deeply($th->columns->[-2], $mocks->{'Column::Timestamp'});
    is_deeply($args->{'Column::Timestamp'}, ['updated_at', $options,
                                             'created_at', $options]);
};

subtest 'references creates and pushes a reference column' => sub {
    my $th = Migrate::Table->new('my_table');
    my $col_count = scalar @{ $th->columns };
    my $options = { };
    $th->references('my_column', $options);

    is(scalar @{ $th->columns }, $col_count + 1);
    is_deeply($th->columns->[-1], $mocks->{'Column::References'});
    is_deeply($args->{'Column::References'}, ['my_table', 'my_column', $options]);
};

subtest 'to_sql returns a SQL representation of a create table without primary key' => sub {
    my $th = Migrate::Table->new('my_table', { id => 0 });
    $th->column('my_column', 'string');
    is($th->to_sql, 'CREATE TABLE schema.my_table (<COLUMN>)');
};

subtest 'to_sql returns a SQL representation of a create table statement' => sub {
    my $th = Migrate::Table->new('my_table');
    $th->column('my_column', 'string');
    is($th->to_sql, 'CREATE TABLE schema.my_table (<PK_COLUMN>,<COLUMN>)');
};

subtest 'to_sql returns a SQL representation of a table with options' => sub {
    my $th = Migrate::Table->new('my_table', { options => 'my options' });
    $th->column('my_column', 'string');
    $th->column('my_column', 'integer');
    is($th->to_sql, 'CREATE TABLE schema.my_table (<PK_COLUMN>,<COLUMN>,<COLUMN>) my options');
};

subtest 'to_sql returns a SQL representation of a table with timestamps' => sub {
    my $th = Migrate::Table->new('my_table', { options => 'my options' });
    $th->column('my_column', 'string');
    $th->timestamps;
    is($th->to_sql, 'CREATE TABLE schema.my_table (<PK_COLUMN>,<COLUMN>,<TIMESTAMP>,<TIMESTAMP>) my options');
};

subtest 'to_sql returns a SQL representation of a table with references' => sub {
    my $th = Migrate::Table->new('my_table', { options => 'my options' });
    $th->column('my_column', 'string');
    $th->references('dept');
    is($th->to_sql, 'CREATE TABLE schema.my_table (<PK_COLUMN>,<COLUMN>,<REFERENCE>) my options');
};

subtest 'to_sql returns a SQL representation of a temporary table' => sub {
    my $th = Migrate::Table->new('my_table', { temporary => 1 });

    no warnings 'redefine';
    local *Migrate::Table::temporary = sub { 'TEMPORARY' };
    use warnings 'redefine';

    $th->column('my_column', 'string');
    is($th->to_sql, 'CREATE TEMPORARY TABLE schema.my_table (<PK_COLUMN>,<COLUMN>)');
};

done_testing();
