use strict;
use warnings;

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use File::Path qw(remove_tree make_path);
use File::Spec;

use Migrate::Datatype;

subtest 'new default implementation is always invalid' => sub {
    trap { Migrate::Datatype->new('integer') };
    like($trap->die, qr/^Invalid datatype: integer/);
};

my $module = new Test::MockModule('Migrate::Datatype');
$module->mock('datatypes', { string => 'VARCHAR', integer => 'INTEGER' });

# After implementing datatypes

subtest 'new returns a valid object if the name is valid' => sub {
    my $dt = Migrate::Datatype->new('integer');
    is($dt->name, 'integer');
};

subtest 'new is invalid if not a valid datatype' => sub {
    trap { Migrate::Datatype->new('not_valid_dt') };
    like($trap->die, qr/Invalid datatype: not_valid_dt/);
};

subtest 'new is valid and defaults to string if datatype looks like number' => sub {
    my $dt = Migrate::Datatype->new(1);
    is($dt->name, 'string');

    $dt = Migrate::Datatype->new(145);
    is($dt->name, 'string');
};

subtest 'new fallsback to a default datatype if not specified' => sub {
    my $dt = Migrate::Datatype->new();
    is($dt->name, 'string');
};

subtest 'is SQLizable' => sub {
    my $col = Migrate::Datatype->new('integer');
    isa_ok($col, "Migrate::SQLizable");
};

subtest 'name returns the datatype API name' => sub {
    my $dt = Migrate::Datatype->new('string');
    is($dt->name, 'string');
};

subtest 'native_name returns the datatype implemented DB name' => sub {
    my $dt = Migrate::Datatype->new('string');
    is($dt->native_name, 'VARCHAR');
};

subtest 'limit returns the limit from initialization' => sub {
    my $dt = Migrate::Datatype->new('string', { limit => 34 });
    is($dt->limit, 34);
};

subtest 'precision returns the precision from initialization' => sub {
    my $dt = Migrate::Datatype->new('string', { precision => 12 });
    is($dt->precision, 12);
};

subtest 'scale returns the scale from initialization' => sub {
    my $dt = Migrate::Datatype->new('string', { scale => 52 });
    is($dt->scale, 52);
};

sub get_dbh { Test::MockObject->new()->mock('quote', sub { "/$_[1]/" }) }

subtest 'quote quotes the given value depending on the datatype' => sub {
    my $dt = Migrate::Datatype->new('string');
    my $module = new Test::MockModule('Migrate::Datatype')->mock('get_dbh', get_dbh);
    is($dt->quote(45), '/45/');
};

subtest 'quote does not quote the given value depending on the datatype' => sub {
    my $dt = Migrate::Datatype->new('integer');
    my $module = new Test::MockModule('Migrate::Datatype')->mock('get_dbh', get_dbh);
    is($dt->quote(45), 45);
};

subtest 'to_sql returns the DB datatype name if no option is set' => sub {
    my $dt = Migrate::Datatype->new('string');
    is($dt->to_sql, 'VARCHAR');
};

subtest 'to_sql returns the DB datatype with a limit if limit is set' => sub {
    my $dt = Migrate::Datatype->new('string', { limit => 33 });
    is($dt->to_sql, 'VARCHAR(33)');
};

subtest 'to_sql returns the DB datatype with a precision if precision is set' => sub {
    my $dt = Migrate::Datatype->new('integer', { precision => 83 });
    is($dt->to_sql, 'INTEGER(83)');
};

subtest 'to_sql returns the DB datatype with a precision and scale if precision and scale are set' => sub {
    my $dt = Migrate::Datatype->new('string', { precision => 83, scale => 4 });
    is($dt->to_sql, 'VARCHAR(83,4)');
};

subtest 'to_sql returns the DB datatype name only if precision is not set and scale is set' => sub {
    my $dt = Migrate::Datatype->new('integer', { scale => 4 });
    is($dt->to_sql, 'INTEGER');
};

done_testing();
