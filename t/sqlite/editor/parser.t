use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use Migrate::Factory qw(id);
use Migrate::SQLite::Editor::Util qw(unquote);

use Migrate::SQLite::Editor::Parser qw(:all);

my $constraint = new Test::MockModule('Migrate::Config');
$constraint->mock('config', { dsn => 'dbi:SQLite:sample' });

# NOTE: These modules works on the assumption of well formed SQL because
# they always come from a query to sqlite_master. For that reason it doesn't
# dies or return errors.

subtest 'get_tokens tokenizes a string by keywords/literals, quoted strings and parenthesized expressions' => sub {
    my $test = qq{  this "identifier" \t and"another ""test"")"(with (complex 45 "(expr"))6.7'other''s'   (null)  };
    my $res = [ get_tokens($test) ];
    is_deeply($res, ['this', '"identifier"', 'and' , '"another ""test"")"', '(with (complex 45 "(expr"))', '6.7', "'other''s'", '(null)']);
};

subtest 'parse_constraint_tokens returns first token if not recognized and consumes it' => sub {
    my $sql = 'test sql command';
    my $tokens = ['my', 'tokens', '"string"'];
    my $res = parse_constraint_tokens($tokens);
    is($res, 'my');
    ok(!ref($res));
    is_deeply($tokens, ['tokens', '"string"']);
};

subtest 'parse_constraint_tokens returns a Constraint object from tokens if recognized' => sub {
    my $sql = 'test sql command';
    my $tokens = [qw(NOT NULL rest)];
    my $cns = parse_constraint_tokens($tokens);
    is($cns->type, 'NOT NULL');
    is($cns->name, undef);
    is_deeply($tokens, ['rest']);
};

subtest 'parse_constraint_tokens returns a named Constraint from tokens if recognized' => sub {
    my $sql = 'test sql command';
    my $tokens = [qw(CONSTRAINT name NOT NULL rest)];
    my $cns = parse_constraint_tokens($tokens);
    is($cns->type, 'NOT NULL');
    is($cns->name, 'name');
    is_deeply($tokens, ['rest']);
};

subtest 'parse_constraint_tokens returns an quoted named Constraint from tokens if recognized' => sub {
    my $sql = 'test sql command';
    my $tokens = [qw(CONSTRAINT "na""me" NOT NULL rest)];
    my $cns = parse_constraint_tokens($tokens);
    is($cns->type, 'NOT NULL');
    is($cns->name, 'na"me');
    is_deeply($tokens, ['rest']);
};

# Helps test constraints using unamed, named and quoted named variations.
sub test_parse_constraint_tokens  {
    my $type = shift;
    my @samples = @_; # Support many samples to test. They'll be added to the constraint type.
    my @names = (undef, 'cname', '"c""name"');

    for my $sample (@samples) {
        $sample = " $sample" if $sample;

        for my $name (@names) {
            # Lets test this with upper and lower case SQL statements
            test_constraint_helper($name, $type, $sample, 1);
            test_constraint_helper($name, $type, $sample, 0);
        }
    }
}

# Helper to Assemble a test case, use $upper to setermine upper or lower case
sub test_constraint_helper {
    my ($name, $expected_type, $sample, $upper) = @_;
    # assemble input
    my $const = $upper? 'CONSTRAINT' : 'constraint';
    my $prefix = $name? "$const $name " : '';
    my $type = $expected_type;

    $type = $upper? uc($type) : lc($type);
    $sample = $upper? uc($sample) : lc($sample);

    my $input = "$prefix$type$sample rest";

    # assemble expected output (constraint keyword and type are always uppercased)
    my $expected_prefix = $name? 'CONSTRAINT '.id(unquote($name)).' ' : '';
    my $expected = "$expected_prefix$expected_type$sample";

    # uncomment this to get a feedback of expectations
    # diag("$input => $expected");

    my $tokens = [get_tokens($input)]; # Tokenize
    my $c = parse_constraint_tokens($tokens);
    is($c->type, $expected_type); # constraint is always uppercased
    is($c->name, unquote($name)); # name is always unquoted
    is($c->to_sql, $expected);
    is_deeply($tokens, ['rest']); # it consumes tokens until constraint becomes invalid
}

subtest 'parse_constraint_tokens parses not null' => sub {
    my @samples = qw(ROLLBACK ABORT FAIL IGNORE REPLACE);
    test_parse_constraint_tokens ('NOT NULL', '', (map { "ON CONFLICT $_" } @samples));
};

subtest 'parse_constraint_tokens parses null' => sub {
    my @samples = qw(ROLLBACK ABORT FAIL IGNORE REPLACE);
    test_parse_constraint_tokens ('NULL', '', (map { "ON CONFLICT $_" } @samples));
};

subtest 'parse_constraint_tokens parses default (quoted literals)' => sub {
    my @samples = ('""', "''", "'my ''string'", '"my ""string"');
    test_parse_constraint_tokens ('DEFAULT', @samples);
};

subtest 'parse_constraint_tokens parses default (numerals and keywords)' => sub {
    my @samples = ('3', '4.5', '.5', '-3', '-4.5', '-.5', '+3', '+4.5', '+.5', 'NULL');
    test_parse_constraint_tokens ('DEFAULT', @samples);
};

subtest 'parse_constraint_tokens parses default (parenthesized expr)' => sub {
    my @samples = ('()', '(8)', "((4 + 6) * ((3) + () - 2) + 'string_with_)')");
    test_parse_constraint_tokens ('DEFAULT', @samples);
};

subtest 'parse_constraint_tokens parses foreign_key' => sub {
    my @samples = ('table', '"ta""ble"');
    test_parse_constraint_tokens ('REFERENCES', @samples);
    test_parse_constraint_tokens ('REFERENCES', 'table (col1, "col2")');
};

subtest 'parse_constraint_tokens parses foreign_key on_delete' => sub {
    my @samples_on_delete = map { "tablex on delete $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
    test_parse_constraint_tokens ('REFERENCES', @samples_on_delete);

    @samples_on_delete = map { "tablex (x, \"y\") on delete $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
    test_parse_constraint_tokens ('REFERENCES', @samples_on_delete);
};

subtest 'parse_constraint_tokens parses foreign_key on_update' => sub {
    my @samples_on_delete = map { "tablex on update $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
    test_parse_constraint_tokens ('REFERENCES', @samples_on_delete);

    @samples_on_delete = map { "tablex (x, \"y\") on update $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
    test_parse_constraint_tokens ('REFERENCES', @samples_on_delete);
};

subtest 'parse_constraint_tokens parses foreign_key match' => sub {
    test_parse_constraint_tokens ('REFERENCES', 'tabley match name');
    test_parse_constraint_tokens ('REFERENCES', 'tabley match "name"');
};

subtest 'parse_constraint_tokens parses foreign_key all rules' => sub {
    my @samples_on = map { "tablex match name on delete $_ on update $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
    test_parse_constraint_tokens ('REFERENCES', @samples_on);

    @samples_on = map { "tablex (col) on delete $_ match name on update $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
    test_parse_constraint_tokens ('REFERENCES', @samples_on);
};

subtest 'parse_constraint_tokens parses foreign_key deferrable' => sub {
    my @samples = map { 'table deferrable'.($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint_tokens ('REFERENCES', @samples);

    @samples = map { 'table (x,y) deferrable'.($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint_tokens ('REFERENCES', @samples);
};

subtest 'parse_constraint_tokens parses foreign_key not deferrable' => sub {
    my @samples = map { 'table (x,y) not deferrable'.($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint_tokens ('REFERENCES', @samples);

    @samples = map { 'table (x,y) not deferrable'.($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint_tokens ('REFERENCES', @samples);
};

subtest 'parse_constraint_tokens parses foreign_key deferrable with rules' => sub {
    my $prefix = 'on update no action match "name" on delete restrict';
    my @samples = map { "table $prefix deferrable".($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint_tokens ('REFERENCES', @samples);

    @samples = map { "table (x,y) $prefix deferrable".($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint_tokens ('REFERENCES', @samples);
};

subtest 'parse_constraint_tokens parses foreign_key not deferrable with rules' => sub {
    my $prefix = 'on update no action match "name" on delete restrict';
    my @samples = map { "table $prefix not deferrable".($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint_tokens ('REFERENCES', @samples);

    @samples = map { "table (x,y) $prefix not deferrable".($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint_tokens ('REFERENCES', @samples);
};

subtest 'parse_constraint tokenizes and parses tokens' => sub {
    my $input_sql = 'Input SQL';
    my @tokens = ('my', 'tokens');
    my ($sql_param, $tokens_param);
    my $parser = Test::MockModule->new('Migrate::SQLite::Editor::Parser');
    $parser->redefine('get_tokens', sub { $sql_param = shift; @tokens });
    $parser->redefine('parse_constraint_tokens', sub { $tokens_param = shift; 'results' });

    is(parse_constraint($input_sql), 'results');
    is($sql_param, $input_sql);
    is_deeply(\@tokens, $tokens_param);
};

subtest 'parse_column_tokens parses a column' => sub {
    my $tokens = ['column_name', 'INT'];
    my $col = parse_column_tokens($tokens);
    isa_ok($col, 'Migrate::SQLite::Editor::Column');
    is_deeply($tokens,[] ); # always consume all tokens
};

subtest 'parse_column_tokens parses column name' => sub {
    my $tokens = ['column_name', 'INT'];
    my $col = parse_column_tokens($tokens);
    is($col->name, 'column_name');
    is_deeply($tokens,[] );
};

subtest 'parse_column_tokens parses quoted column name' => sub {
    my $tokens = ['"column""name"', 'INT'];
    my $col = parse_column_tokens($tokens);
    is($col->name, 'column"name');
    is_deeply($tokens,[] );
};

subtest 'parse_column_tokens parses column datatype' => sub {
    my $tokens = ['column_name', 'INT'];
    my $col = parse_column_tokens($tokens);
    isa_ok($col->type, 'Migrate::SQLite::Editor::Datatype');
    is_deeply($tokens,[] );
};

subtest 'parse_column_tokens supports all SQLite native datatypes' => sub {
    my @datatypes = (
        'INT', 'INTEGER', 'TINYINT', 'SMALLINT', 'BIGINT', 'UNSIGNED BIG INT', 'INT2', 'INT8',
        'CHARACTER', 'VARCHAR', 'VARYING CHARACTER', 'NCHAR', 'NATIVE CHARACTER', 'NVARCHAR',
        'TEXT', 'CLOB', 'BLOB', 'REAL', 'DOUBLE', 'DOUBLE PRECISION', 'NUMERIC', 'DECIMAL',
        'BOOLEAN', 'DATE', 'DATETIME');

    for (@datatypes)  {
        my $tokens = ['column_name', split(' ', $_)];
        my $col = parse_column_tokens($tokens);
        is($col->type->native_name, $_);
        is_deeply($tokens,[] );

        $tokens = ['column_name', map { lc($_) } split(' ', $_)];
        $col = parse_column_tokens($tokens);
        is($col->type->native_name, $_);
        is_deeply($tokens, []);
    }
};

subtest 'parse_column_tokens supports columns without datatype' => sub {
    my $tokens = ['column_name', 'ANYTHING'];
    my $col = parse_column_tokens($tokens);
    is($col->type->native_name, '');
    is($col->constraints->[0], 'ANYTHING'); # remaining is treated as constraint
    is_deeply($tokens, []);
};

subtest 'parse_column_tokens parses constraints with paser_contraint_tokens until no more tokens' => sub {
    my $tokens = ['column_name', 'INT', 'UNKNOWN', 'TOKEN', 'KNOWN', 'TOKEN', 'STREAM', 'rest'];

    my $index = 0;
    my $fake_constraint = Test::MockObject->new();
    my $parser = Test::MockModule->new('Migrate::SQLite::Editor::Parser');
    $parser->redefine(
        'parse_constraint_tokens',
        sub {
            my $t = shift;
            if ($index++ == 2) { # only when index is 2 recognize tokens as multi-token constraint
                splice(@$t, 0, 3); # and remove as many tokens as required to create constraint
                return $fake_constraint;
            }
            return shift(@$t);
        }
    );

    my $col = parse_column_tokens($tokens);
    is($col->constraints->[0], 'UNKNOWN');
    is($col->constraints->[1], 'TOKEN');
    is($col->constraints->[2], $fake_constraint); # just in case (is_deeply compares hashes deeply, not references)
    is($col->constraints->[3], 'rest');
    is_deeply($tokens, []);
};

subtest 'parse_column tokenizes and parses tokens' => sub {
    my $input_sql = 'Input SQL';
    my @tokens = ('my', 'tokens');
    my ($sql_param, $tokens_param);
    my $parser = Test::MockModule->new('Migrate::SQLite::Editor::Parser');
    $parser->redefine('get_tokens', sub { $sql_param = shift; @tokens });
    $parser->redefine('parse_column_tokens', sub { $tokens_param = shift; 'result' });

    is(parse_column($input_sql), 'result');
    is($sql_param, $input_sql);
    is_deeply(\@tokens, $tokens_param);
};


subtest 'split_columns splits a column list SQL string into an array of SQL columns (simple)' => sub {
    my $input = qq{ \n\t col1 INT, col2 VARCHAR, col3  \t };
    my @res = split_columns($input);
    is_deeply(\@res, ['col1 INT', 'col2 VARCHAR', 'col3']);
};

subtest 'split_columns splits a column list SQL string into an array of SQL columns (quoted)' => sub {
    # will ignore commas and parenthesis inside quoted expressions.
    my $input = qq{col1 INT "quo""ted", col2 VARCHAR "quoted with ),", col3 'ot(her'};
    my @res = split_columns($input);
    is_deeply(\@res, ['col1 INT "quo""ted"', 'col2 VARCHAR "quoted with ),"', "col3 'ot(her'"]);
};

subtest 'split_columns splits a column list SQL string into an array of SQL columns (parenthesized)' => sub {
    # parenthesized expressions will expext properly balanced parenthesis ignoring parenthesis
    # inside quote or double quoted strings.
    my $input = 'col1 INT, col2 VARCHAR (c1, c2) ("val )," + (8, 9, 10)), col3';
    my @res = split_columns($input);
    is_deeply(\@res, ['col1 INT', 'col2 VARCHAR (c1, c2) ("val )," + (8, 9, 10))', 'col3']);
};

subtest 'parse_table returns a table named after the create table SQL' => sub {
    for (('create table table_name (columns)', 'CREATE TABLE table_name(COLUMNS)')) {
        my $tb = parse_table($_);
        isa_ok($tb, 'Migrate::SQLite::Editor::Table');
        is($tb->name, 'table_name');
    }
};

subtest 'parse_table returns a table named after the create table SQL' => sub {
    for (('create table "table""name" (columns)', 'CREATE TABLE "table""name"(COLUMNS)')) {
        my $tb = parse_table($_);
        isa_ok($tb, 'Migrate::SQLite::Editor::Table');
        is($tb->name, 'table"name');
    }
};

subtest 'parse_table set everything after the column parenthesis as options' => sub {
    my $input = 'CREATE TABLE "table""name"(COLUMNS) all my options';
    my $tb = parse_table($input);
    is($tb->postfix, 'all my options');
};

subtest 'parse_table uses split_columns to split content inside parenthesis and parse_column' => sub {
    my $input_sql = 'create table x(cols)';
    my $index = 0;
    my @column_sqls = ('col1 INT', 'col2');
    my @columns = (Test::MockObject->new, Test::MockObject->new);
    my ($sql_param, @col_params);
    my $parser = Test::MockModule->new('Migrate::SQLite::Editor::Parser');
    $parser->redefine('split_columns', sub { $sql_param = shift; @column_sqls });
    $parser->redefine('parse_column', sub { push(@col_params, shift); $columns[$index++] });

    my $tb = parse_table($input_sql);
    is($sql_param, 'cols'); # receives sql
    is_deeply(\@col_params, ['col1 INT', 'col2']); # receives split_columns results
    is($tb->columns->[0], $columns[0]);
    is($tb->columns->[1], $columns[1]);
};

subtest 'parse_index parses an index name' => sub {
    my @inputs = (
        'CREATE INDEX index_name ON table_name(cols1, cols2)',
        'create index index_name on table_name(cols1, cols2)',
    );
    for my $input (@inputs) {
        my $idx = parse_index($input);
        isa_ok($idx, 'Migrate::SQLite::Index');
        is($idx->name, 'index_name');
    }
};

subtest 'parse_index parses an index quoted name' => sub {
    my @inputs = (
        'CREATE INDEX "index""name" ON table_name(cols1, cols2)',
        'create index"index""name" on table_name(cols1, cols2)',
        'create index "index""name"ON table_name(cols1, cols2)',
        'create index"index""name"ON table_name(cols1, cols2)',
    );
    for my $input (@inputs) {
        my $idx = parse_index($input);
        is($idx->name, 'index"name');
    }
};

subtest 'parse_index parses an index table_name' => sub {
    my @inputs = (
        'CREATE INDEX index_name ON table_name(cols1, cols2)',
        'create index index_name on table_name (cols1, cols2)',
    );
    for my $input (@inputs) {
        my $idx = parse_index($input);
        is($idx->table, 'table_name');
    }
};

subtest 'parse_index parses an index quoted table_name' => sub {
    my @inputs = (
        'CREATE INDEX index_name ON "table""name" (cols1, cols2)',
        'create index index_name on "table""name"(cols1, cols2)',
        'create index index_name ON"table""name" (cols1, cols2)',
        'create index index_name ON"table""name"(cols1, cols2)',
    );
    for my $input (@inputs) {
        my $idx = parse_index($input);
        is($idx->table, 'table"name');
    }
};

subtest 'parse_index parses an index columns' => sub {
    my @inputs = (
        'CREATE INDEX index_name ON table_name (col1 , col2)',
        'create index index_name on table_name (col1,col2)',
    );
    for my $input (@inputs) {
        my $idx = parse_index($input);
        is_deeply($idx->columns, [qw(col1 col2)]);
    }
};

subtest 'parse_index parses an index quoted columns' => sub {
    my @inputs = (
        'CREATE INDEX index_name ON table_name ("col""1" , "col""2")',
        'create index index_name on table_name ("col""1","col""2")',
    );
    for my $input (@inputs) {
        my $idx = parse_index($input);
        is_deeply($idx->columns, [qw(col"1 col"2)]);
    }
};

subtest 'parse_index parses an index with options' => sub {
    my $idx = parse_index('CREATE INDEX index_name ON table_name (col1) WHERE 1 ');
    is($idx->options, 'WHERE 1');
};

# This is the only case we make it fail because this process is not token based
# but regex based instead. We want to assure we get user feedback if the pattern
# fails in specific edge cases.
subtest 'parse_index dies if pattern does not match' => sub {
    trap { parse_index('create index bad format') };
    like($trap->die, qr/^Pattern coould not match: create index bad format/);
};

done_testing();
