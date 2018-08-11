package Migrate::SQLite::Editor::Parser;

use strict;
use warnings;

BEGIN {
    use parent qw(Exporter);
    our @EXPORT_OK = qw(parse_table parse_column parse_index parse_constraint parse_datatype);
}

use Migrate::SQLite::Editor::Util qw(unquote trim);
use Migrate::SQLite::Editor::Datatype;
use Migrate::SQLite::Editor::Constraint;

my $datatypes_str = join('|', keys %Migrate::SQLite::Editor::Datatype::datatypes);
my $attributes_re = qr/\((?<opts>[^)]+)\)/io;

my $squoted_re = qr/'(?:[^']++|'')*+'/;
my $dquoted_re = qr/"(?:[^"]++|"")*+"/;

my $id_re = qr/$dquoted_re|\w+/; #identifier
my $quoted_re = qr/$squoted_re|$dquoted_re/; #quoted
my $paren_re = qr/(\((?:[^()"']++|$quoted_re|(?-1))*+\))/; #parenthesis
my $column = qr/((?:[^("',]++|$paren_re|$quoted_re)++),?/;

sub _get_columns {
    my ($str, @cols) = (shift);
    push(@cols, trim($1)) while($str =~ /\G$column/go);
    return @cols;
}

sub parse_table {
    my $sql = shift;
    $sql =~ s/^\s*create\s+table(?:\s+(\w+)|\s*($dquoted_re))\s*\(//i;
    my $name = unquote($1 || $2);
    $sql =~ s/(\)[^\)]*)$//;
    my $postfix = $1;
    my @columns = map { parse_column($_) } _get_columns($sql);
    return Migrate::SQLite::Editor::Table->new($name, $postfix, @columns);
}

sub parse_column {
    my $sql = shift;
    my @tokens = _get_tokens($sql);
    my $name = _parse_name(shift(@tokens)) // die("Needs valid column name in SQL: $sql");
    my $datatype = _parse_datatype(\@tokens);
    my @constraints = _parse_constraints(\@tokens);
    return Migrate::SQLite::Editor::Column->new($name, $datatype, @constraints);
}

sub parse_index {
    my $sql = shift;
    $sql =~ /^\s*create\s+(?<unique>unique\s+)?index\s*(?<index>$id_re)\s*on\s*(?<table>$id_re)\s*\((?<cols>.*)\)/i;
    my $name = unquote($+{index});
    my $table = unquote($+{table});
    my $options = { unique => !!$+{unique} };
    my $columns = [ map { unquote(trim($_)) } split(',', $+{cols}) ];
    return Migrate::SQLite::Editor::Index->new($name, $table, $columns, $options);
}

sub parse_datatype { _parse_datatype([ _get_tokens(shift) ]) }
sub parse_constraint { _parse_constraint([ _get_tokens(shift) ]) }

sub _get_tokens {
    my $sql = shift // die('Needs column SQL');
    return grep { length($_ // '') } split /$paren_re|($quoted_re)|\s+/, $sql;
}

sub _parse_name {
    my $name = shift;
    $name =~ s/^"//;
    $name =~ s/"$//;
    $name =~ s/""/"/g;
    return $name;
}

sub _parse_datatype {
    my $tokens = shift;
    my @datatype = ($tokens->[0] // '');
    my $next_token = ($tokens->[1] // '');

    push(@datatype, $next_token) if $datatype[0] =~ /^unsigned|varying|native$/i;
    push(@datatype, $next_token) if $datatype[0] =~ /^double$/i && $next_token =~ /^precision$/i;

    my $name = join(' ', @datatype);
    return if $name !~ /^(?:$datatypes_str)$/io;
    splice(@$tokens, 0, scalar(@datatype));

    my @attrs;
    if ($tokens->[0] && $tokens->[0] =~ /^$attributes_re$/o) {
        shift(@$tokens);
        @attrs = map { trim($_) } split(qr/\s*,\s*/, $+{opts}, 2) if $+{opts};
    }
    return Migrate::SQLite::Editor::Datatype->new($name, @attrs);
}

sub _parse_constraints {
    my $tokens = shift;
    my ($token, @constraints);
    push @constraints, _parse_constraint($tokens) while (@$tokens);
    return @constraints;
}

sub _parse_constraint {
    my $tokens = shift;
    my $token = shift(@$tokens);
    return $token unless $token =~ /^(?:constraint|default|references|not|null)$/i;

    my @result;
    my $name = $token =~ /^constraint$/i? shift(@$tokens) : undef;
    my $type = $name? shift(@$tokens) : $token;
    return ($token, $name, $type) unless $type =~ /^(?:default|references|not)$/i;

    my @pred;
    if ($type =~ /^not$/i && $tokens->[0] =~ /^null$/i) {
        $type .= ' '.shift(@$tokens);
        @pred = splice(@$tokens, 0, 3) if $tokens->[0] && $tokens->[0] =~ /^on$/;
    }
    push @pred, shift(@$tokens) if ($type =~ /^default$/i);
    @pred = _parse_foreign_key($tokens) if ($type =~ /^references$/i);

    return Migrate::SQLite::Editor::Constraint->new($name, $type, @pred);
}

sub _parse_foreign_key {
    my $tokens = shift;
    my @pred = (shift(@$tokens));

    push(@pred, shift(@$tokens)) if $tokens->[0] =~ /^\(/;

    while ((my $rule = $tokens->[0] // '') =~ /^(?:on|match)$/i) {
        push @pred, splice(@$tokens, 0, 2);

        if ($rule =~ /^on$/i) {
            my $c = $tokens->[0] =~ /^(?:set|no)$/i? 2 : 1;
            push @pred, splice(@$tokens, 0, $c);
        }
    }

    if ($tokens->[0] && $tokens->[0] =~ /^(?:not|deferrable)$/i) {
        my $def_type = shift(@$tokens);
        push @pred, $def_type;
        push @pred, shift(@$tokens) if $def_type =~ /^not$/i;
        push @pred, splice(@$tokens, 0, 2) if $tokens->[0] =~ /^initially$/i;
    }
    return @pred;
}

return 1;
