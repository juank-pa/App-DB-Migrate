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
use Migrate::Util;
use Migrate::Datatype;
use Migrate::SQLite::Editor::Column;

no warnings 'redefine';
local *Migrate::Util::identifier_name = sub { my $str = shift; $str =~ s/"/""/g; $str };
use warnings;

my @cases = (
    [qq{column_name prefix }, qq{ postfix more}],
    [qq{column_name prefix \t }, qq{ \t postfix more}],
    [qq{column_name "pr""efix"}, qq{ postfix more}],
    [qq{column_name prefix }, qq{"pos""tfix" more}],
    [qq{column_name "pr""efix"}, qq{"pos""tfix" more}],
    [qq{column_name "prefix" \t }, qq{ \t "postfix" more}],
    [qq{column_name (pr(e)"fi"x)}, qq{ postfix more}],
    [qq{column_name prefix }, qq{(pos(t)f"i"x) more}],
    [qq{column_name (pr(e)f"i"x)}, qq{(pos(t)"f"ix) more}],
    [qq{column_name (pr(e)"f""i"x) \t }, qq{ \t (pos(t)fix) more}],
);

my @ucases = map { [ uc($_->[0]), uc($_->[1]) ] } @cases;

sub _edge_case_tester {
    my ($input, $sub) = @_;
    my @inputs = @{ $input };
    for my $i (@inputs) {
        for my $c (@cases) {
            my $space = $i =~ /(["'])$/ && $c->[1] =~ /^$1/? ' ' : '';
            my $case = "$c->[0]\L$i\E$space$c->[1]";
            my $col = Migrate::SQLite::Editor::Column->new($case);
            $sub->($col, $case, @$c);
        }

        for my $c (@ucases) {
            my $space = $i =~ /(["'])$/ && $c->[1] =~ /^$1/? ' ' : '';
            my $case = uc("$c->[0]\U$i\E$space$c->[1]");
            my $col = Migrate::SQLite::Editor::Column->new($case);
            $sub->($col, $case, @$c);
        }
    }
}

sub _constraint_edge_case_tester {
    my $input = shift;
    my $sub = shift;
    my @consts = ('constraint cname ', 'constraint "cname" ', 'constraint "cname"','constraint"cname" ','constraint"cname"');
    for my $i (@$input) {
        _edge_case_tester([map { "$_$i" } @consts], $sub);
    }
}

sub triml { (my $st = shift) =~ s/^\s+//; $st }
sub trimr { (my $st = shift) =~ s/\s+$//; $st }
sub trim { trimr(triml($_[0])) }

our $params = {};
our $mocks = {
    datatype => MockStringifiedObject->new('<DATATYPE>'),
    default => MockStringifiedObject->new('<DEFAULT>'),
    foreignkey => MockStringifiedObject->new('<FOREIGN_KEY>'),
};

no warnings 'redefine';
local *Migrate::SQLite::Editor::Column::create = sub {
    my $type = lc((split('::', $_[0]))[-1]);
    $params->{$type} = \@_; $mocks->{$type}
};
use warnings 'redefine';

subtest 'new creates a new editor column object' => sub {
    isa_ok(Migrate::SQLite::Editor::Column->new('any'), 'Migrate::SQLite::Editor::Column');
};

subtest 'name parses the name from the SQL sentence' => sub {
    my $col = Migrate::SQLite::Editor::Column->new('column_name anything else');
    is($col->name, 'column_name');

    $col = Migrate::SQLite::Editor::Column->new('"quoted ""name""" anything else');
    is($col->name, 'quoted "name"');

    $col = Migrate::SQLite::Editor::Column->new(' "other_name" anything else');
    is($col->name, 'other_name');

    $col = Migrate::SQLite::Editor::Column->new(" \tother_name2 anything else");
    is($col->name, 'other_name2');
};

subtest 'rename updates the column name in the SQL sentence' => sub {
    my $col = Migrate::SQLite::Editor::Column->new('column_name anything else');
    $col->rename('new "name"');
    is($col, '"new ""name""" anything else');
    is($col->name, 'new "name"');

    $col = Migrate::SQLite::Editor::Column->new('"quoted ""name""" anything else');
    $col->rename('my_new_quoted_name');
    is($col, '"my_new_quoted_name" anything else');
    is($col->name, 'my_new_quoted_name');

    $col = Migrate::SQLite::Editor::Column->new('  "other_name" anything else');
    $col->rename('another other_name');
    is($col, qq{"another other_name" anything else});
    is($col->name, 'another other_name');

    $col = Migrate::SQLite::Editor::Column->new(" \t other_name2 and something else");
    $col->rename('anything');
    is($col, qq{"anything" and something else});
    is($col->name, 'anything');
};

# DATATYPE

my %expected_datatypes = (
    INT                 => 'integer',
    INTEGER             => 'integer',
    TINYINT             => 'integer',
    SMALLINT            => 'integer',
    BIGINT              => 'bigint',
    'UNSIGNED BIG INT'  => 'bigint',
    INT2                => 'integer',
    INT8                => 'integer',
    CHARACTER           => 'char',
    VARCHAR             => 'string',
    'VARYING CHARACTER' => 'string',
    NCHAR               => 'char',
    'NATIVE CHARACTER'  => 'char',
    NVARCHAR            => 'string',
    TEXT                => 'text',
    CLOB                => 'text',
    BLOB                => 'binary',
    REAL                => 'float',
    DOUBLE              => 'float',
    'DOUBLE PRECISION'  => 'float',
    NUMERIC             => 'numeric',
    DECIMAL             => 'decimal',
    BOOLEAN             => 'boolean',
    DATE                => 'date',
    DATETIME            => 'datetime',
);

subtest 'dataype maps the SQL datatype to an app datatype' => sub {
    for my $datatype (keys (%expected_datatypes)) {
        my $col = Migrate::SQLite::Editor::Column->new("column_name $datatype anything else");
        is($col->datatype, $expected_datatypes{$datatype});
    }

    for my $datatype (keys (%expected_datatypes)) {
        my $col = Migrate::SQLite::Editor::Column->new("column_name   \L$datatype\E(4,5) anything else");
        is($col->datatype, $expected_datatypes{$datatype});
    }
};

subtest 'dataype returns the limit/precision and scale if present in array context' => sub {
    my $col = Migrate::SQLite::Editor::Column->new("column_name DOUBLE( 4 , 5 ) anything else");
    is_deeply([($col->datatype)], ['float', 4, 5]);

    $col = Migrate::SQLite::Editor::Column->new("column_name INTEGER  (23) anything else");
    is_deeply([($col->datatype)], ['integer', 23]);

    $col = Migrate::SQLite::Editor::Column->new(qq{"column_name"DECIMAL(2) anything else});
    is_deeply([($col->datatype)], ['decimal', 2]);
};

subtest 'dataype is undef if not present' => sub {
    my $col = Migrate::SQLite::Editor::Column->new("column_name no type");
    is_deeply($col->datatype, undef);
};

subtest 'change_datatype changes the datatype using the given data' => sub {
    my $options = { opts => 1 };

    my $col = Migrate::SQLite::Editor::Column->new("column_name DOUBLE(4,5) anything else");
    $col->change_datatype('any_type', $options);
    is_deeply($params->{'datatype'}, ['datatype', 'any_type', $options]);
    is($col, 'column_name <DATATYPE> anything else');

    $col = Migrate::SQLite::Editor::Column->new(qq{"column_name"INTEGER anything else});
    $col->change_datatype('any_type', $options);
    is_deeply($params->{'datatype'}, ['datatype', 'any_type', $options]);
    is($col, '"column_name" <DATATYPE> anything else');

    $col = Migrate::SQLite::Editor::Column->new(qq{"column_name" no type or anything else});
    $col->change_datatype('any_typex', $options);
    is_deeply($params->{'datatype'}, ['datatype', 'any_typex', $options]);
    is($col, '"column_name" <DATATYPE> no type or anything else');
};

subtest 'change_datatype does not change datatype if exactly equal' => sub {
    my $options = { };
    $mocks->{datatype}->mock('build_attrs', sub { '4,5' });

    my $col = Migrate::SQLite::Editor::Column->new("column_name DOUBLE (4 , 5 ) anything else");
    $col->change_datatype('float', $options);
    is_deeply($params->{'datatype'}, ['datatype', 'float', $options]);
    is($col, 'column_name DOUBLE (4 , 5 ) anything else');
};

## DEFAULT

subtest 'change_default removes a previous default if undef (quoted literal)' => sub {
    _edge_case_tester(['DEFAULT "col"', "DEFAULT \t 'quoted''str'", 'default"string"'], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_default(undef);
        is($col, trimr($prefix).' '.triml($postfix), "Case: $case");
    });
};

subtest 'change_default removes a previous default if undef (unquoted literal)' => sub {
    my @vals = qw(TRUE FALSE NULL CURRENT_DATE CURRENT_TIME CURRENT_TIMESTAMP identifer_col4);
    _edge_case_tester([map { "DEFAULT $_" } @vals], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_default(undef);
        is($col, trimr($prefix).' '.triml($postfix), "Case: $case");
    });

    @vals = qw(54 5.5 .7 8. 8.6E5 -54 -5.5 -.7 -8. -8.6E53 +54 +5.5 +.7 +8. +8.6E5);
    _edge_case_tester([map { "DEFAULT $_" } @vals], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_default(undef);
        is($col, trimr($prefix).' '.triml($postfix), "Case: $case");
    });
};

subtest 'change_default removes a previous default if undef (balanced parenthesized expression)' => sub {
    my @vals = ('(any)', qq{(8 + 'test''str(ing' * (subexpr "ot""her" + (8 + 9) - (19)))});
    _edge_case_tester([map { "DEFAULT $_" } @vals], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_default(undef);
        is($col, trimr($prefix).' '.triml($postfix), "Case: $case");
    });
};

subtest 'change_default removes a previous default if undef (named constraint)' => sub {
    my @vals = ("('8(')", '""', '5', 'NULL');
    _constraint_edge_case_tester([map { "DEFAULT $_" } @vals], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_default(undef);
        is($col, trimr($prefix).' '.triml($postfix), "Case: $case");
    });
};

subtest 'change_default replaces a previous default if value sent (quoted literal)' => sub {
    no warnings 'redefine';
    local *Migrate::SQLite::Editor::Column::datatype = sub { 'test_datatype' };
    use warnings;

    _edge_case_tester(['DEFAULT "col"', "DEFAULT \t 'quoted''str'", 'default"string"'], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_default('any_val');
        is_deeply($params->{'datatype'}, ['datatype', 'test_datatype']);
        is_deeply($params->{'default'}, ['Constraint::Default', 'any_val', { type => $mocks->{datatype} }]);
        is($col, trimr($prefix).' <DEFAULT> '.triml($postfix), "Case: $case");
    });
};

subtest 'change_default replaces a previous default if value sent (unquoted literal)' => sub {
    no warnings 'redefine';
    local *Migrate::SQLite::Editor::Column::datatype = sub { 'test_datatype' };
    use warnings;

    my @vals = qw(TRUE FALSE NULL CURRENT_DATE CURRENT_TIME CURRENT_TIMESTAMP identifer_col4);
    _edge_case_tester([map { "DEFAULT $_" } @vals], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_default('any_value');
        is_deeply($params->{'datatype'}, ['datatype', 'test_datatype']);
        is_deeply($params->{'default'}, ['Constraint::Default', 'any_value', { type => $mocks->{datatype} }]);
        is($col, trimr($prefix).' <DEFAULT> '.triml($postfix), "Case: $case");
    });

    @vals = qw(54 5.5 .7 8. 8.6E5 -54 -5.5 -.7 -8. -8.6E53 +54 +5.5 +.7 +8. +8.6E5);
    _edge_case_tester([map { "DEFAULT $_" } @vals], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_default('any_value');
        is_deeply($params->{'datatype'}, ['datatype', 'test_datatype']);
        is_deeply($params->{'default'}, ['Constraint::Default', 'any_value', { type => $mocks->{datatype} }]);
        is($col, trimr($prefix).' <DEFAULT> '.triml($postfix), "Case: $case");
    });
};

subtest 'change_default replaces a previous default if value sent (balanced parenthesized expression)' => sub {
    no warnings 'redefine';
    local *Migrate::SQLite::Editor::Column::datatype = sub { 'test_datatype' };
    use warnings;

    my @vals = ('(any)', qq{(8 + 'test''str(ing' * (subexpr "ot""her" + (8 + 9) - (19)))});
    _edge_case_tester([map { "DEFAULT $_" } @vals], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_default('any_value');
        is_deeply($params->{'datatype'}, ['datatype', 'test_datatype']);
        is_deeply($params->{'default'}, ['Constraint::Default', 'any_value', { type => $mocks->{datatype} }]);
        is($col, trimr($prefix).' <DEFAULT> '.triml($postfix), "Case: $case");
    });
};

subtest 'change_default replaces a previous default if value sent (named constraint)' => sub {
    no warnings 'redefine';
    local *Migrate::SQLite::Editor::Column::datatype = sub { 'test_datatype' };
    use warnings;

    my @vals = ("('8(')", '""', '5', 'NULL');
    _constraint_edge_case_tester([map { "DEFAULT $_" } @vals], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_default('any_value');
        is_deeply($params->{datatype}, ['datatype', 'test_datatype']);
        my $cname = ord($case) >= ord('a')? 'cname' : 'CNAME';
        is_deeply($params->{default}, ['Constraint::Default', 'any_value', { type => $mocks->{datatype}, name => $cname }]);
        is($col, trimr($prefix).' <DEFAULT> '.triml($postfix), "Case: $case");
    });
};

subtest 'change_default appends a default if a value is sent and SQL not present' => sub {
    no warnings 'redefine';
    local *Migrate::SQLite::Editor::Column::datatype = sub { 'test_datatype' };
    use warnings;

    _edge_case_tester([''], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_default('any_val');
        is_deeply($params->{'datatype'}, ['datatype', 'test_datatype']);
        is_deeply($params->{'default'}, ['Constraint::Default', 'any_val', { type => $mocks->{datatype} }]);
        is($col, "$case <DEFAULT>", "Case: $case");
    });
};

subtest 'change_default does nothing did not have a default and undef' => sub {
    _edge_case_tester([''], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_default(undef);
        is($col, $case, "Case: $case");
    });
};

# NULL

subtest 'is_null returns true if column does not contain NOT NULL' => sub {
    _edge_case_tester(['', 'null', 'NULL'], sub {
        ok($_[0]->is_null, "Case: $_[1]");
    });
};

subtest 'is_null returns false if column contains NOT NULL' => sub {
    _edge_case_tester(['not null', 'NOT NULL'], sub {
        ok(!$_[0]->is_null, "Case: $_[1]");
    });
};

subtest 'is_null does not take into account quoted or parenthesized content' => sub {
    _edge_case_tester(['"quoted not null string"', "'quoted not null string'", '(enclosed NOT NULL string)'], sub {
        ok($_[0]->is_null, "Case: $_[1]");
    });
};

subtest 'change_null removes not null if true' => sub {
    _edge_case_tester(['NOT NULL', 'not null', "not \t\n null"], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_null(1);
        ok($col->is_null, "Case: $case");
        is($col, trimr($prefix).' '.triml($postfix));
    });
};

subtest 'change_null removes constrained not null if true' => sub {
    _constraint_edge_case_tester(['not null'], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_null(1);
        ok($col->is_null, "Case: $case");
        is($col, trimr($prefix).' '.triml($postfix));
    });
};

subtest 'change_null does not modify SQL if true is sent and null' => sub {
    _edge_case_tester(['NULL'], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->change_null(1);
        is($col, $case);
    });
};

subtest 'change_null does remove null if false' => sub {
    TODO: {
        local $TODO = 'change_null: find a reliable way to remove a previous non quoted/parenthesized null';

        my $col = Migrate::SQLite::Editor::Column->new("column_name NULL anything else");
        $col->change_null(0);
        is($col, "column_name anything else NOT NULL");
    }
};

# FOREIGN_KEY

subtest 'remove_foreign_key does nothing if foreign key not found' => sub {
    _edge_case_tester(['', 'REFERENCES'], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->remove_foreign_key();
        is($col, $case);
    });
};

subtest 'remove_foreign_key removes the foreign key if found' => sub {
    _edge_case_tester(['references table (id)', 'references "table" ("id")', 'references"table" (id)', 'references "table"(id)', 'references"table"(id)'], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->remove_foreign_key();
        is($col, trimr($prefix).' '.triml($postfix));
    });
};

subtest 'remove_foreign_key removes the foreign key if found (constrained)' => sub {
    _constraint_edge_case_tester(['references table (id)', 'references "table" ("id")', 'references"table" (id)', 'references "table"(id)', 'references"table"(id)'], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        $col->remove_foreign_key();
        is($col, trimr($prefix).' '.triml($postfix));
    });
};

subtest 'add_foreign_key does nothing if foreign key is found' => sub {
    _edge_case_tester(['references table (id)', 'references "table" ("id")', 'references"table" (id)', 'references "table"(id)', 'references"table"(id)'], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        my $options = { opts => 1 };
        $col->add_foreign_key('table1', 'table2', $options);
        is($col, $case);
    });
};

subtest 'add_foreign_key does nothing if foreign key is found (constrained)' => sub {
    _constraint_edge_case_tester(['references table (id)', 'references "table" ("id")', 'references"table" (id)', 'references "table"(id)', 'references"table"(id)'], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        my $options = { opts => 1 };
        $col->add_foreign_key('table1', 'table2', $options);
        is($col, $case);
    });
};

subtest 'add_foreign_key adds the foreign key if not found' => sub {
    _edge_case_tester([''], sub {
        my ($col, $case, $prefix, $postfix) = @_;
        my $options = { opts => 1 };
        $col->add_foreign_key('departments', 'users', $options);
        is_deeply($params->{foreignkey}, ['Constraint::ForeignKey', 'departments', 'users', $options]);
        is($col, "$case <FOREIGN_KEY>");
    });
};

done_testing();
