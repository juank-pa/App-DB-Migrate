package App::DB::Migrate::SQLite::Editor::Parser;

use strict;
use warnings;

BEGIN {
    use parent qw(Exporter);
    our %EXPORT_TAGS = (
        util => [qw(split_columns get_tokens)],
        string => [qw(parse_table parse_column parse_constraint parse_index)],
        tokens => [qw(parse_constraint_tokens parse_column_tokens)],
    );
    {
        my %seen;
        push @{$EXPORT_TAGS{all}},
            grep {!$seen{$_}++} @{$EXPORT_TAGS{$_}} foreach keys %EXPORT_TAGS;
    }
    Exporter::export_tags('all');
}

use App::DB::Migrate::SQLite::Editor::Util qw(unquote trim);
use App::DB::Migrate::SQLite::Editor::Datatype;
use App::DB::Migrate::SQLite::Editor::Constraint;
use App::DB::Migrate::SQLite::Editor::Column;
use App::DB::Migrate::SQLite::Editor::Table;
use App::DB::Migrate::SQLite::Index;

my $datatypes_str = join('|', keys %App::DB::Migrate::SQLite::Editor::Datatype::datatypes);
my $attributes_re = qr/\((?<opts>[^)]+)\)/;

my $squoted_re = qr/'(?:[^']++|'')*+'/;
my $dquoted_re = qr/"(?:[^"]++|"")*+"/;

my $id_re = qr/$dquoted_re|\w+/; #identifier
my $quoted_re = qr/$squoted_re|$dquoted_re/; #quoted
my $paren_re = qr/(\((?:[^()"']++|$quoted_re|(?-1))*+\))/; #balanced parenthesis
my $column = qr/((?:[^("',]++|$paren_re|$quoted_re)++),?/;

sub split_columns {
    my ($str, @cols) = (shift);
    push(@cols, trim($1)) while($str =~ /\G$column/go);
    return @cols;
}

sub parse_table {
    my $sql = shift // die('Table SQL needed');
    $sql =~ s/^\s*create\s+table(?:\s+(\w+)|\s*($dquoted_re))\s*\(//io;
    my $name = unquote($1 || $2);
    $sql =~ s/\)\s*([^\)]*)$//;
    my $postfix = $1;
    my @columns = map { parse_column($_) } split_columns($sql);
    return App::DB::Migrate::SQLite::Editor::Table->new($name, $postfix, @columns);
}

sub parse_column { parse_column_tokens([ get_tokens(shift) ]) }

sub parse_index {
    my $sql = shift // die('Index SQL needed');
    die("Pattern could not match: $sql") unless
        $sql =~ /^\s*create\s+(?<unique>unique\s+)?index\s*(?<index>$id_re)\s*on\s*(?<table>$id_re)\s*\((?<cols>.*)\)(?<options>.*)/io;
    my $cols = $+{cols};
    my $name = unquote($+{index});
    my $table = unquote($+{table});
    my $options = { unique => !!$+{unique}, name => $name, options => trim($+{options})  };
    my $columns = [ map { unquote(trim($_)) } split(',', $cols) ];
    return App::DB::Migrate::SQLite::Index->new($table, $columns, $options);
}

sub parse_constraint { parse_constraint_tokens([ get_tokens(shift) ]) }

sub get_tokens {
    my $sql = shift // die('Needs column SQL');
    return grep { length($_ // '') } split /$paren_re|($quoted_re)|\s+/o, $sql;
}

sub parse_column_tokens {
    my $tokens = shift;
    my $name = unquote(shift(@$tokens));
    my $datatype = _parse_datatype($tokens);
    my @constraints = _parse_constraints($tokens);
    return App::DB::Migrate::SQLite::Editor::Column->new($name, $datatype, @constraints);
}

sub parse_constraint_tokens {
    my $tokens = shift;
    my ($name, $type) = _parse_constraint_name_and_type($tokens);
    return shift(@$tokens) unless $type;

    my @pred = _parse_constraint_predicate($type, $tokens);
    return App::DB::Migrate::SQLite::Editor::Constraint->new($name, $type, @pred);
}

sub _parse_datatype {
    my $tokens = shift;
    my @datatype = ($tokens->[0] // '');

    push(@datatype, $tokens->[1]) if $datatype[0] =~ /^varying|native$/i;
    push(@datatype, @$tokens[1, 2]) if $datatype[0] =~ /^unsigned$/i;
    push(@datatype, $tokens->[1]) if $datatype[0] =~ /^double$/i && $tokens->[1] && $tokens->[1] =~ /^precision$/i;

    my $name = join(' ', @datatype);
    return if $name !~ /^(?:$datatypes_str)$/io;
    splice(@$tokens, 0, scalar(@datatype));

    return App::DB::Migrate::SQLite::Editor::Datatype->new($name, _parse_datatype_attributes($tokens));
}

sub _parse_datatype_attributes {
    my $tokens = shift;
    if ($tokens->[0] && $tokens->[0] =~ /^$attributes_re$/o) {
        shift(@$tokens);
        return map { trim($_) } split(qr/\s*,\s*/, $+{opts}, 2) if $+{opts};
    }
    return ();
}

sub _parse_constraints {
    my $tokens = shift;
    my @constraints;
    push @constraints, parse_constraint_tokens($tokens) while @$tokens;
    return @constraints;
}

sub _parse_constraint_name_and_type {
    my $tokens = shift;
    my $token = $tokens->[0];
    return unless $token =~ /^(?:constraint|default|references|not|null)$/i;

    my $name = $token =~ /^constraint$/i? $tokens->[1] : undef;
    my $type = $name? $tokens->[2] : $token;
    return unless $type =~ /^(?:default|references|not|null)$/i;

    $name? splice(@$tokens, 0, 3) : shift(@$tokens);
    $type .= ' '.shift(@$tokens) if $type =~ /^not$/i;
    return (unquote($name), $type);
}

sub _parse_constraint_predicate {
    my ($type, $tokens) = @_;
    my @pred;
    my @parsers = (\&_parse_null, \&_parse_default, \&_parse_foreign_key);
    for my $parser (@parsers) {
        return @pred if @pred = $parser->($type, $tokens);
    }
    return ();
}

sub _parse_default {
    my ($type, $tokens) = @_;
    return $type =~ /^default$/i? (shift(@$tokens)) : ();
}

sub _parse_null {
    my ($type, $tokens) = @_;
    if ($type =~ /^(?:not )?null$/i && $tokens->[0] && $tokens->[0] =~ /^on$/i) {
        return splice(@$tokens, 0, 3);
    }
    return ();
}

sub _parse_foreign_key {
    my ($type, $tokens) = @_;
    return () unless $type =~ /^references$/i;

    my @pred = (shift(@$tokens));

    # parse columns, rules and deferrable properties
    push(@pred, shift(@$tokens)) if $tokens->[0] && $tokens->[0] =~ /^\(/;
    push(@pred, _parse_foreign_key_rules($tokens));
    push(@pred, _parse_foreign_key_deferrable($tokens));
    return @pred;
}

sub _parse_foreign_key_rules {
    my ($tokens, @pred) = @_;

    while ((my $rule = $tokens->[0] // '') =~ /^(?:on|match)$/i) {
        push @pred, splice(@$tokens, 0, 2);

        if ($rule =~ /^on$/i) {
            my $c = $tokens->[0] =~ /^(?:set|no)$/i? 2 : 1;
            push @pred, splice(@$tokens, 0, $c);
        }
    }

    return @pred;
}

sub _parse_foreign_key_deferrable {
    my ($tokens, @pred) = @_;

    if ($tokens->[0] && $tokens->[0] =~ /^(?:not|deferrable)$/i) {
        my $def_type = shift(@$tokens);
        push @pred, $def_type;
        push @pred, shift(@$tokens) if $def_type =~ /^not$/i;
        push @pred, splice(@$tokens, 0, 2) if $tokens->[0] && $tokens->[0] =~ /^initially$/i;
    }

    return @pred;
}

return 1;
