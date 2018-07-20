use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use MockStringifiedObject;

use Migrate::Column::PrimaryKey;

my $datatype = MockStringifiedObject->new('<DATATYPE>')
    ->mock('is_valid_datatype', sub { shift; $_[0] && grep /^string|integer$/, @_ });

my $mocks = {
    datatype => $datatype,
    'Constraint::PrimaryKey' => MockStringifiedObject->new('<PK_CONSTRAINT>'),
};
my $args = {};

our $fail = 0;

no warnings 'redefine';
local *Migrate::Column::PrimaryKey::class = sub { $datatype if $_[0] eq 'datatype' };
local *Migrate::Column::PrimaryKey::create = sub {
    die("Failure\n") if $fail;

    my ($type, @args) = @_;
    $args->{$type} = \@args;
    return $mocks->{$type};
};
local *Migrate::Column::create = *Migrate::Column::PrimaryKey::create;
use warnings 'redefine';

my $util = Test::MockModule->new('Migrate::Util');
$util->mock('identifier_name', sub { 'schema.'.$_[0] });

subtest 'PrimaryKey new creates a primary key column' => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table');
    isa_ok($pk, 'Migrate::Column::PrimaryKey');
    isa_ok($pk, 'Migrate::Column');
};

subtest 'PrimaryKey new fails if table name not set' => sub {
    trap { Migrate::Column::PrimaryKey->new('') };
    is($trap->die, "Table name needed\n");
};

subtest 'PrimaryKey sets the column name to id if not provided' => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table');
    is($pk->name, 'id');
};

subtest 'PrimaryKey sets the column name to a custom name if provided' => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table', 'my_id_custom');
    is($pk->name, 'my_id_custom');
};

subtest 'PrimaryKey sets the column dataype to integer if not provided' => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table', { limit => 1, other => 3 });
    is_deeply($args->{'datatype'}, ['integer', { limit => 1 }]);
};

subtest 'PrimaryKey sets the column dataype to a custom type if provided' => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table', { limit => 1, type => 'string' });
    is_deeply($args->{'datatype'}, ['string', { limit => 1 }]);
};

subtest 'PrimaryKey new creates a primary key column with a primary key constraint' => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table');
    is($pk->primary_key_constraint, $mocks->{'Constraint::PrimaryKey'});
    is($pk->constraints->[-1], $mocks->{'Constraint::PrimaryKey'});
    is_deeply($args->{'Constraint::PrimaryKey'}, ['my_table', 'id', {}]);
};

subtest 'PrimaryKey new passes autoincrement to constraint' => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table', { autoincrement => 1 });
    is_deeply($args->{'Constraint::PrimaryKey'}, ['my_table', 'id', { autoincrement => 1 }]);
};

subtest 'PrimaryKey new does not pass autoincrement to constraint if unsupported type' => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table', { autoincrement => 1, type => 'string' });
    is_deeply($args->{'Constraint::PrimaryKey'}, ['my_table', 'id', { }]);
};

subtest 'PrimaryKey passes constraint as the constraint name' => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table', { name => 'my_pk_constraint' });
    is_deeply($args->{'Constraint::PrimaryKey'}, ['my_table', 'id', { name => 'my_pk_constraint' }]);
};

subtest 'PrimaryKey passes a custom column name to constraint' => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table', 'custom_column');
    is_deeply($args->{'Constraint::PrimaryKey'}, ['my_table', 'custom_column', { }]);
};

subtest 'table returns the table name', => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table', { column => 'custom_column' });
    is($pk->table, 'my_table');
};

subtest 'autoincrements returns the constraint autoincrements', => sub {
    my $constraint = Test::MockObject->new()->mock('autoincrements', sub { 'ANYTHING' });
    local $mocks->{'Constraint::PrimaryKey'} = $constraint;
    my $pk = Migrate::Column::PrimaryKey->new('my_table', { column => 'custom_column' });
    is($pk->autoincrements, 'ANYTHING');
};

subtest 'to_sql returns SQL representation of primary key', => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table');
    is($pk->to_sql, 'id <DATATYPE> <PK_CONSTRAINT>');
};

subtest 'to_sql returns SQL representation of primary key with custom column', => sub {
    my $pk = Migrate::Column::PrimaryKey->new('my_table', 'my_column');
    is($pk->to_sql, 'my_column <DATATYPE> <PK_CONSTRAINT>');
};

done_testing();
