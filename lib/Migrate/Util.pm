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

sub identifier_name {
    my $table_name = shift;
    my $config = Migrate::Config::config;
    return get_dbh()->quote_identifier($config->{catalog}, $config->{schema}, $table_name);
}

sub join_elems { join ' ', grep { $_ } @_ }

return 1;
