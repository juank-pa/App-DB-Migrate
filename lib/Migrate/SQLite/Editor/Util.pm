package Migrate::SQLite::Editor::Util;

use strict;
use warnings;

BEGIN {
    use parent qw(Exporter);
    our @EXPORT_OK = qw(trim unquote);
}

sub trim {
    my $str = shift;
    return $str unless $str;
    $str =~ s/^\s+//o;
    $str =~ s/\s+$//o;
    return $str;
}

sub unquote {
    my $str = shift;
    return $str unless $str && $str =~ /^".*"$/o;
    $str =~ s/^"//o;
    $str =~ s/"$//o;
    $str =~ s/""/"/go;
    return $str;
}

return 1;
