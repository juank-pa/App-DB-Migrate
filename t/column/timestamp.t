use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::Trap;
use Mocks;

use Migrate::Column::Timestamp;

subtest 'new creates a timestamp column' => sub {
    my $ts = Migrate::Column::Timestamp->new('my_table');
    isa_ok($ts, 'Migrate::Column::Timestamp');
};

subtest 'new fails if column fails' => sub {
    fail_factory();
    trap { Migrate::Column::Timestamp->new('') };
    is($trap->die, "Test issue\n");
};

subtest 'new sets the column name' => sub {
    Migrate::Column::Timestamp->new('col_name');
    ok_factory_nth(COL, 0, 'col_name');
};

subtest 'new always sets the datatype to datetime' => sub {
    Migrate::Column::Timestamp->new('col_name', { type => 'anything' });
    ok_factory_nth(COL, 1, 'datetime');
};

subtest 'new copies options to column' => sub {
    Migrate::Column::Timestamp->new('col_name', { type => 'anything', options => 'any' });
    ok_factory_nth(COL, 2, { type => 'anything', options => 'any', default => { timestamp => 1 } });
};

subtest 'new replaces default option with timestamp' => sub {
    Migrate::Column::Timestamp->new('col_name', { default => 'different' });
    ok_factory_nth(COL, 2, { default => { timestamp => 1 } });
};

subtest 'Timestamp delegates methods to column' => sub {
    my @methods = qw(name options type constraints index to_sql);
    my $ts = Migrate::Column::Timestamp->new('my_table', { name => 'custom_name' });

    for my $method (@methods) {
        get_mock(COL)->mock($method, sub { "Called $method" });
        is($ts->$method(), "Called $method", "Method $method was not delegated");
    }
};

subtest 'is SQLizable' => sub {
    my $ts = Migrate::Column::Timestamp->new('table');
    isa_ok($ts, "Migrate::SQLizable");
};

done_testing();
