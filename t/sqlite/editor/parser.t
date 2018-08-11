use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockModule;
use Test::Trap;
use Migrate::Factory qw(id);
use Migrate::SQLite::Editor::Util qw(unquote);

use Migrate::SQLite::Editor::Parser qw(parse_table parse_column parse_index parse_constraint get_tokens);

my $constraint = new Test::MockModule('Migrate::Config');
$constraint->mock('config', { dsn => 'dbi:SQLite:sample' });

subtest 'get_tokens tokenizes a string by keywords/literals, quoted strings and parenthesized expressions' => sub {
    my $test = qq{  this "identifier" \t and"another ""test"")"(with (complex 45 "(expr"))6.7'other''s'   (null)  };
    my $res = [ get_tokens($test) ];
    is_deeply($res, ['this', '"identifier"', 'and' , '"another ""test"")"', '(with (complex 45 "(expr"))', '6.7', "'other''s'", '(null)']);
};

subtest 'parse_constraint returns first token result if not recognized' => sub {
    my $sql = 'test sql command';
    my $sent_sql;
    my $parser = new Test::MockModule('Migrate::SQLite::Editor::Parser');
    $parser->mock('get_tokens', sub { $sent_sql = $_[0]; ('my', 'tokens', '"string"') });

    is(parse_constraint($sql), 'my');
    is($sent_sql, $sql);
};

subtest 'parse_constraint returns a Constraint object from tokens if recognized' => sub {
    my $sql = 'test sql command';
    my $parser = new Test::MockModule('Migrate::SQLite::Editor::Parser');
    $parser->mock('get_tokens', sub { ('not','null') });

    my $res = parse_constraint('any');
    isa_ok($res, 'Migrate::SQLite::Editor::Constraint');
    is($res->type, 'NOT NULL');
    ok(!$res->name);
};

subtest 'parse_constraint returns a named Constraint from tokens if recognized' => sub {
    my $parser = new Test::MockModule('Migrate::SQLite::Editor::Parser');
    $parser->mock('get_tokens', sub { ('constraint', 'cname', 'not','null') });

    my $res = parse_constraint('any');
    isa_ok($res, 'Migrate::SQLite::Editor::Constraint');
    is($res->type, 'NOT NULL');
    is($res->name, 'cname');
};

subtest 'parse_constraint returns an quoted named Constraint from tokens if recognized' => sub {
    my $parser = new Test::MockModule('Migrate::SQLite::Editor::Parser');
    $parser->mock('get_tokens', sub { ('constraint', '"cna""me"', 'not','null') });

    my $res = parse_constraint('any');
    isa_ok($res, 'Migrate::SQLite::Editor::Constraint');
    is($res->type, 'NOT NULL');
    is($res->name, 'cna"me');
};

# Helps test constraints using unamed, named and quoted named variations.
# Helper will test normalized SQL (correctly space separated).
# There is no need to test correct tokenization due to having it already tested.
sub test_parse_constraint {
    my $type = shift;
    my @samples = @_;
    my @names = (undef, 'cname', '"c""name"');
    #@samples = @samples || ('');

    for my $sample (@samples) {
        $sample = " $sample" if $sample;
        for my $name (@names) {
            my $prefix = $name? "constraint $name " : '';
            my $sql = "$prefix\L$sample\E";
            my @cases = (lc($sql), uc($sql));

            test_constraint_helper($name, $type, $sample, 1);
            test_constraint_helper($name, $type, $sample, 0);
        }
    }
}

# We do tests with upper and lower case so we use a helper for that
sub test_constraint_helper {
    my ($name, $type, $sample, $upper) = @_;
    my $const = $upper? 'CONSTRAINT' : 'constraint';

    my $prefix = $name? "$const $name " : '';
    my $expected_prefix = $name? 'CONSTRAINT '.id(unquote($name)).' ' : '';

    $sample = $upper? uc($sample) : lc($sample);
    my $sample_type = $upper? uc($type) : lc($type);

    my $c = parse_constraint("$prefix$sample_type$sample do not parse this");
    #diag("$prefix$sample_type$sample <=> $expected_prefix$type$sample");
    is($c->type, $type);
    is($c->name, unquote($name));
    is($c->to_sql, "$expected_prefix$type$sample");
}

subtest 'parse_constraint parses not null' => sub {
    my @samples = qw(ROLLBACK ABORT FAIL IGNORE REPLACE);
    test_parse_constraint('NOT NULL', '', (map { "ON CONFLICT $_" } @samples));
};

subtest 'parse_constraint parses null' => sub {
    my @samples = qw(ROLLBACK ABORT FAIL IGNORE REPLACE);
    test_parse_constraint('NULL', '', (map { "ON CONFLICT $_" } @samples));
};

subtest 'parse_constraint parses default (quoted literals)' => sub {
    my @samples = ('""', "''", "'my ''string'", '"my ""string"');
    test_parse_constraint('DEFAULT', @samples);
};

subtest 'parse_constraint parses default (numerals and keywords)' => sub {
    my @samples = ('3', '4.5', '.5', '-3', '-4.5', '-.5', '+3', '+4.5', '+.5', 'NULL');
    test_parse_constraint('DEFAULT', @samples);
};

subtest 'parse_constraint parses default (parenthesized expr)' => sub {
    my @samples = ('()', '(8)', "((4 + 6) * ((3) + () - 2) + 'string_with_)')");
    test_parse_constraint('DEFAULT', @samples);
};

subtest 'parse_constraint parses foreign_key' => sub {
    my @samples = ('table', '"ta""ble"');
    test_parse_constraint('REFERENCES', @samples);
    test_parse_constraint('REFERENCES', 'table (col1, "col2")');
};

subtest 'parse_constraint parses foreign_key on_delete' => sub {
    my @samples_on_delete = map { "tablex on delete $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
    test_parse_constraint('REFERENCES', @samples_on_delete);

    @samples_on_delete = map { "tablex (x, \"y\") on delete $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
    test_parse_constraint('REFERENCES', @samples_on_delete);
};

subtest 'parse_constraint parses foreign_key on_update' => sub {
    my @samples_on_delete = map { "tablex on update $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
    test_parse_constraint('REFERENCES', @samples_on_delete);

    @samples_on_delete = map { "tablex (x, \"y\") on update $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
    test_parse_constraint('REFERENCES', @samples_on_delete);
};

subtest 'parse_constraint parses foreign_key match' => sub {
    test_parse_constraint('REFERENCES', 'tabley match name');
    test_parse_constraint('REFERENCES', 'tabley match "name"');
};

subtest 'parse_constraint parses foreign_key all rules' => sub {
    my @samples_on = map { "tablex match name on delete $_ on update $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
    test_parse_constraint('REFERENCES', @samples_on);

    @samples_on = map { "tablex (col) on delete $_ match name on update $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
    test_parse_constraint('REFERENCES', @samples_on);
};

subtest 'parse_constraint parses foreign_key deferrable' => sub {
    my @samples = map { 'table deferrable'.($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint('REFERENCES', @samples);

    @samples = map { 'table (x,y) deferrable'.($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint('REFERENCES', @samples);
};

subtest 'parse_constraint parses foreign_key not deferrable' => sub {
    my @samples = map { 'table (x,y) not deferrable'.($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint('REFERENCES', @samples);

    @samples = map { 'table (x,y) not deferrable'.($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint('REFERENCES', @samples);
};

subtest 'parse_constraint parses foreign_key deferrable with rules' => sub {
    my $prefix = 'on update no action match "name" on delete restrict';
    my @samples = map { "table $prefix deferrable".($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint('REFERENCES', @samples);

    @samples = map { "table (x,y) $prefix deferrable".($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint('REFERENCES', @samples);
};

subtest 'parse_constraint parses foreign_key not deferrable with rules' => sub {
    my $prefix = 'on update no action match "name" on delete restrict';
    my @samples = map { "table $prefix not deferrable".($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint('REFERENCES', @samples);

    @samples = map { "table (x,y) $prefix not deferrable".($_? " $_" : '') } ("", 'initially deferred', 'initially immediate');
    test_parse_constraint('REFERENCES', @samples);
};

#subtest 'parse_constraint parses foreign_key all rules' => sub {
#    my @samples_on = map { "tablex match name on delete $_ on update $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
#    test_parse_constraint('REFERENCES', @samples_on);
#
#    @samples_on = map { "tablex on delete $_ match name on update $_" } ('set null', 'set default', 'cascade', 'restrict', 'no action');
#    test_parse_constraint('REFERENCES', @samples_on);
#};

done_testing();
