use strict;
use warnings;

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use File::Path qw(remove_tree make_path);
use File::Spec;

use lib 't/lib';
use MockStringifiedObject;
use Migrate::Factory;
use Migrate::Column;

our $params = {};
our $test_die;
our $mocks = {
    datatype => MockStringifiedObject->new('<DATATYPE>'),
    null => MockStringifiedObject->new('<NULL>'),
    default => MockStringifiedObject->new('<DEFAULT>')
};

no warnings 'redefine';
local *Migrate::Column::create = sub {
    die("Test issue\n") if $test_die;

    my $type = lc((split('::', $_[0]))[-1]);
    $params->{$type} = \@_; $mocks->{$type}
};
use warnings 'redefine';

subtest 'new is invalid if datatype fails' => sub {
    local $test_die = 1;
    trap { Migrate::Column->new('column', 'anything') };
    is($trap->die, "Test issue\n");
};

subtest 'new is invalid if no name is given' => sub {
    trap { Migrate::Column->new('', 'integer') };
    is($trap->die, "Column name is needed\n");
};

subtest 'new passes datatype to factory' => sub {
    my $col = Migrate::Column->new('column', 'my_datatype');
    is_deeply($params->{datatype}, ['datatype', 'my_datatype', undef]);
};

subtest 'new passes options to factory' => sub {
    my $col = Migrate::Column->new('column', 'my_datatype', {
        any => 'ANY',
        limit => 23,
        precision => 45,
        scale => 2,
    });
    is_deeply($params->{'datatype'}, ['datatype', 'my_datatype', {limit => 23, precision => 45, scale => 2}]);
    is_deeply($col->options, { any => 'ANY' });
};

subtest 'new create null constraint if passed' => sub {
    local $params->{null};
    my $col = Migrate::Column->new('column_name', 'datatype', { null => 1 });
    is_deeply($params->{null}, ['Constraint::Null', 1]);
    is($col->constraints->[0], $mocks->{null});
};

subtest 'new creates default constraint if passed' => sub {
    local $params->{default};
    my $col = Migrate::Column->new('column_name', 'datatype', { default => 3 });
    is_deeply($params->{default}, ['Constraint::Default', 3, $mocks->{datatype}]);
    is($col->constraints->[0], $mocks->{default});
};

subtest 'new does not create null constraint if not passed' => sub {
    local $params->{null};
    my $col = Migrate::Column->new('column_name', 'datatype', {});
    is($params->{null}, undef);
};

subtest 'new does not create default constraint if not passed' => sub {
    local $params->{default};
    my $col = Migrate::Column->new('column_name', 'datatype', {});
    is($params->{default}, undef);
};

subtest 'options returns the column options' => sub {
    my $options = {};
    my $col = Migrate::Column->new('column', 'datatype', $options);
    is($options, $col->options);
};

subtest 'datatype returns a constructed Datatype object from the the column datatype' => sub {
    my $col = Migrate::Column->new('column', 'datatype');
    is($col->datatype, $mocks->{datatype});
};

subtest 'to_sql returns the column SQL representation' => sub {
    my $col = Migrate::Column->new('column_name', 'datatype');
    is($col->to_sql, 'column_name <DATATYPE>');
};

subtest 'to_sql returns the column SQL representation as not null' => sub {
    my $col = Migrate::Column->new('column_name', 'datatype', { null => 0 });
    is($col->to_sql, 'column_name <DATATYPE> <NULL>');

    $col = Migrate::Column->new('column_name', 'datatype', { null => 1 });
    is($col->to_sql, 'column_name <DATATYPE> <NULL>');

    $col = Migrate::Column->new('column_name', 'datatype', { null => undef });
    is($col->to_sql, 'column_name <DATATYPE> <NULL>');
};

subtest 'to_sql returns the column SQL representation with a default value' => sub {
    my $col = Migrate::Column->new('column_name', 'datatype', { default => 45 });
    is($col->to_sql, 'column_name <DATATYPE> <DEFAULT>');

    $col = Migrate::Column->new('column_name', 'datatype', { null => 0, default => 45 });
    is($col->to_sql, 'column_name <DATATYPE> <NULL> <DEFAULT>');
};

subtest 'Column stringifies as the column SQL representation' => sub {
    my $col = Migrate::Column->new('column_name', 'datatype', { null => 0, default => 45 });
    is("$col", 'column_name <DATATYPE> <NULL> <DEFAULT>');
};

done_testing();
