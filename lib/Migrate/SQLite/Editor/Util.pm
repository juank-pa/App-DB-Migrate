package Migrate::SQLite::Editor::Util;

use strict;
use warnings;

BEGIN {
    use parent qw(Exporter);
    our %EXPORT_TAGS = (
        parse => [qw(trim unquote)],
        re_fun => [qw(get_id_re string_re name_re)],
    );

    push @{ $EXPORT_TAGS{all} }, @{ $EXPORT_TAGS{$_} } foreach keys %EXPORT_TAGS;
    Exporter::export_ok_tags('all');
}

use feature 'say';

# Regular expression to match a given identifier name quoted or unquoted
sub name_re { my $name = quotemeta(shift); qr/($name|"$name")/ }

# Allows setting regex name to better collect matches later
sub _re_name { $_[0]? "<$_[0]>" : ':' }

# Regular expression to match quoted string
sub string_re { my $name = _re_name(shift); qr/"(?$name(?:[^"]++|"")*+)"/ }

# Regular expression to match identifiers
sub get_id_re {
    my $name = shift;
    my $string_re = string_re($name && "q$name");
    my $uname = _re_name($name && "u$name");
    return qr/$string_re|(?$uname\w+)/;
}

sub trim {
    my $str = shift;
    return $str unless $str;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    return $str;
}

sub unquote {
    my $str = shift;
    return $str unless $str && $str =~ /^".*"$/;
    $str =~ s/^"//;
    $str =~ s/"$//;
    $str =~ s/""/"/g;
    return $str;
}

return 1;
