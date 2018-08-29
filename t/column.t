use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::Trap;
use Mocks;

use App::DB::Migrate::Column;

subtest 'new creates a column' => sub {
    my $col = App::DB::Migrate::Column->new('column');
    isa_ok($col, 'App::DB::Migrate::Column');
};

subtest 'new is invalid if datatype fails' => sub {
    fail_factory();
    trap { App::DB::Migrate::Column->new('column', 'anything') };
    is($trap->die, "Test issue\n");
};

subtest 'new is invalid if no name is given' => sub {
    trap { App::DB::Migrate::Column->new('', 'integer') };
    like($trap->die, qr/^Column name is needed/);
};

subtest 'new passes datatype to factory' => sub {
    App::DB::Migrate::Column->new('column', 'my_datatype');
    ok_factory(DATATYPE, ['my_datatype', undef]);
};

subtest 'new passes options to datatype factory' => sub {
    my $options = {
        any => 'ANY',
        limit => 23,
        precision => 45,
        scale => 2,
    };
    my $col = App::DB::Migrate::Column->new('column', 'my_datatype', $options);

    is_deeply($col->options, $options);
    delete($options->{any});
    ok_factory(DATATYPE, ['my_datatype', $options]);
};

subtest 'new creates null constraint if passed' => sub {
    clear_factories();
    my $col = App::DB::Migrate::Column->new('column_name', 'datatype', { null => 1 });
    ok_factory(NULL, [1]);
    is($col->constraints->[0], get_mock(NULL));
};

subtest 'new creates default constraint if passed' => sub {
    clear_factories();
    my $col = App::DB::Migrate::Column->new('column_name', 'datatype', { default => 3 });
    ok_factory(DEFAULT, [3, { type => get_mock(DATATYPE) }]);
    is($col->constraints->[0], get_mock(DEFAULT));
};

subtest 'new does not create null constraint if not passed' => sub {
    clear_factories();
    my $col = App::DB::Migrate::Column->new('column_name', 'datatype', {});
    ok_factory(NULL, undef);
};

subtest 'new does not create default constraint if not passed' => sub {
    clear_factories();
    my $col = App::DB::Migrate::Column->new('column_name', 'datatype', {});
    ok_factory(DEFAULT, undef);
};

subtest 'new creates a name identifier' => sub {
    clear_factories();
    my $col = App::DB::Migrate::Column->new('column_name', 'datatype', {});
    is($col->identifier, 'column_name');
};

subtest 'is SQLizable' => sub {
    my $col = App::DB::Migrate::Column->new('column', 'my_datatype');
    isa_ok($col, "App::DB::Migrate::SQLizable");
};

subtest 'name returns the column identifier name' => sub {
    my $options = {};
    my $col = App::DB::Migrate::Column->new('column', 'datatype', $options);
    $col->identifier->mock('name', sub { 'id_name' });
    is($col->name, 'id_name');
};

subtest 'options returns the column options' => sub {
    my $options = {};
    my $col = App::DB::Migrate::Column->new('column', 'datatype', $options);
    is($options, $col->options);
};

subtest 'type returns a constructed Datatype object from the column datatype' => sub {
    my $col = App::DB::Migrate::Column->new('column', 'datatype');
    is($col->type, get_mock(DATATYPE));
};

subtest 'index returns index options' => sub {
    my $index_options = { any_option => 'test' };
    my $col = App::DB::Migrate::Column->new('column', 'datatype', { index => $index_options });
    is_deeply($col->index, $index_options);
};

subtest 'add_constraint adds a constraint to the column' => sub {
    my $any_constraint = {};
    my $col = App::DB::Migrate::Column->new('column', 'datatype');
    $col->add_constraint($any_constraint);
    is($col->constraints->[-1], $any_constraint);
};

subtest 'to_sql returns the column SQL representation' => sub {
    my $col = App::DB::Migrate::Column->new('column_name', 'datatype');
    is($col->to_sql, 'column_name <DATATYPE>');
};

subtest 'to_sql returns the column SQL representation with null constraint' => sub {
    my $col = App::DB::Migrate::Column->new('column_name', 'datatype', { null => 0 });
    is($col->to_sql, 'column_name <DATATYPE> <NULL>');

    $col = App::DB::Migrate::Column->new('column_name', 'datatype', { null => 1 });
    is($col->to_sql, 'column_name <DATATYPE> <NULL>');

    $col = App::DB::Migrate::Column->new('column_name', 'datatype', { null => undef });
    is($col->to_sql, 'column_name <DATATYPE> <NULL>');
};

subtest 'to_sql returns the column SQL representation with a default value' => sub {
    my $col = App::DB::Migrate::Column->new('column_name', 'datatype', { default => 45 });
    is($col->to_sql, 'column_name <DATATYPE> <DEFAULT>');

    $col = App::DB::Migrate::Column->new('column_name', 'datatype', { null => 0, default => 45 });
    is($col->to_sql, 'column_name <DATATYPE> <NULL> <DEFAULT>');
};

subtest 'to_sql returns the column SQL representation with an added constraint' => sub {
    my $col = App::DB::Migrate::Column->new('column_name', 'datatype');
    $col->add_constraint(MockStringifiedObject->new('<CONSTRAINT1>'));
    $col->add_constraint(MockStringifiedObject->new('<CONSTRAINT2>'));
    is($col->to_sql, 'column_name <DATATYPE> <CONSTRAINT1> <CONSTRAINT2>');
};

done_testing();
