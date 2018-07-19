use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use MockStringifiedObject;

use Migrate::Column::Timestamp;

my $datatype = MockStringifiedObject->new('<DATATYPE>')
    ->mock('is_valid_datatype', sub { shift; $_[0] && grep /^string|integer$/, @_ });

my $mocks = {
    datatype => $datatype,
    'Constraint::Default' => MockStringifiedObject->new('<DEFAULT>'),
    'Constraint::Null' => MockStringifiedObject->new('<NULL>'),
};
my $args = {};

our $fail = 0;

no warnings 'redefine';
local *Migrate::Column::class = sub { $datatype if $_[0] eq 'datatype' };
local *Migrate::Column::create = sub {
    die("Failure\n") if $fail;

    my ($type, @args) = @_;
    $args->{$type} = \@args;
    return $mocks->{$type};
};
use warnings 'redefine';

my $util = Test::MockModule->new('Migrate::Util');
$util->mock('identifier_name', sub { 'schema.'.$_[0] });

subtest 'Timestamp new creates a timestamp column' => sub {
    my $ts = Migrate::Column::Timestamp->new('col_name');
    isa_ok($ts, 'Migrate::Column::Timestamp');
    isa_ok($ts, 'Migrate::Column');
};

subtest 'Timestamp dies if no name is provided' => sub {
    trap { Migrate::Column::Timestamp->new('') };
    is($trap->die, "Column name is needed\n");
};

subtest 'Timestamp sets a default value of timestamp' => sub {
    my $ts = Migrate::Column::Timestamp->new('my_col');
    is_deeply($args->{'Constraint::Default'}, [{ timestamp => 1 }, $datatype]);
};

subtest 'Timestamp passes only null and default to column' => sub {
    my @base_args;
    no warnings 'redefine';
    local *Migrate::Column::new = sub { @base_args = @_; {} };
    use warnings 'redefine';

    my $ts = Migrate::Column::Timestamp->new('my_col', { null => 0, other => 4 });

    is_deeply(\@base_args, ['Migrate::Column::Timestamp', 'my_col', 'datetime', { default => { timestamp => 1 }, null => 0 }]);
};

subtest 'to_sql returns SQL representation of timestamp', => sub {
    my $ts = Migrate::Column::Timestamp->new('my_col');
    is($ts->to_sql, 'my_col <DATATYPE> <DEFAULT>');
};

subtest 'to_sql returns SQL representation of not null timestamp', => sub {
    my $ts = Migrate::Column::Timestamp->new('my_col', { null => 0 });
    is($ts->to_sql, 'my_col <DATATYPE> <NULL> <DEFAULT>');
};

done_testing();
