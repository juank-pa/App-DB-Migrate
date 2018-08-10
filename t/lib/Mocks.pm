package Mocks;

use strict;
use warnings;

use Test::More;

use MockStringifiedObject;
use Migrate::Factory;

BEGIN {
    use parent 'Exporter';
    our @EXPORT = (
        qw(fail_factory ok_factory_nth ok_factory get_mock clear_factories start_agregate end_agregate),
        qw(ID DATATYPE NULL DEFAULT PK COL FK TS ID_COL REF),
    );
}

use constant ID => 'identifier';
use constant DATATYPE => 'datatype';
use constant COL => 'column';
use constant NULL => 'Constraint::Null';
use constant DEFAULT => 'Constraint::Default';
use constant PK => 'Constraint::PrimaryKey';
use constant FK => 'Constraint::ForeignKey';
use constant TS => 'Column::Timestamp';
use constant ID_COL => 'Column::PrimaryKey';
use constant REF => 'Column::References';

my $datatype = MockStringifiedObject->new('<DATATYPE>')
    ->mock('is_valid_datatype', sub { shift; $_[0] && grep /^string|integer$/, @_ });

my $params = {};
my $test_die = 0;
my $agregate = 0;
my $mocks = {
    DATATYPE, $datatype,
    COL, MockStringifiedObject->new('<COLUMN>'),
    NULL, MockStringifiedObject->new('<NULL>'),
    DEFAULT, MockStringifiedObject->new('<DEFAULT>'),
    PK, MockStringifiedObject->new('<PK>'),
    FK, MockStringifiedObject->new('<FK>'),
    TS, MockStringifiedObject->new('<TIMESTAMP>'),
    ID_COL, MockStringifiedObject->new('<ID_COL>'),
    REF, MockStringifiedObject->new('<REF>'),
};

no warnings 'redefine';
*Migrate::Factory::class = sub { $mocks->{$_[0]} };
*Migrate::Factory::create = sub {
    if ($test_die) {
        $test_die = 0;
        die("Test issue\n");
    }

    my $factory = shift;
    return MockStringifiedObject->new($_[0])->mock('name', sub { $_[0] }) if $factory eq ID;

    if ($agregate) { push(@{ $params->{$factory} }, @_) }
    else { $params->{$factory} = [@_] }

    $mocks->{$factory};
};
use warnings 'redefine';

sub fail_factory {
    $test_die = 1;
}

sub clear_factories {
    my @factories = @_;
    if (@factories) { delete $params->{$_} for @factories }
    else { $params = {} }
}

sub ok_factory {
    my $factory = shift;
    my $expected_params = shift;
    is_deeply($params->{$factory}, $expected_params, "Expected params for $factory failed");
}

sub ok_factory_nth {
    my $factory = shift;
    my $nth = shift;
    my $expected = shift;
    is_deeply($params->{$factory}->[$nth], $expected, "Expected params for $factory [$nth] failed");
}

sub get_mock {
    my $factory = shift;
    $mocks->{$factory};
}

sub start_agregate { $agregate = 1 }
sub end_agregate { $agregate = 0 }

return 1;
