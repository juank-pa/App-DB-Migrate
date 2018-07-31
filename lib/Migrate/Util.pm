package Migrate::Util;

use Migrate::Config;
use Migrate::Dbh qw{get_dbh};

sub extract_keys {
    my $hash = shift;
    my @keys = @{ shift(@_) };
    my $force_delete = shift;
    return if !defined $hash;

    my %ret = map { exists $hash->{$_}? ($_ => $hash->{$_}) : () } @keys;
    if($force_delete) { delete $hash->{$_} for(@keys) }
    return \%ret;
}

sub qualified_name {
    my $table_name = shift;
    return unless $table_name;
    my $config = Migrate::Config::config;
    return get_dbh()->quote_identifier($config->{catalog}, $config->{schema}, $table_name);
}

sub identifier_name {
    my $id_name = shift;
    return unless $id_name;
    my $config = Migrate::Config::config;
    return get_dbh()->quote_identifier(undef, undef, $id_name);
}

sub join_elems { join ' ', grep { defined($_) && length($_) } @_ }

return 1;
