package App::DB::Migrate::Util;

use App::DB::Migrate::Config;
use App::DB::Migrate::Dbh qw{get_dbh};
use Lingua::EN::Inflexion qw(noun verb);

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
    my $config = App::DB::Migrate::Config::config;
    return get_dbh()->quote_identifier($config->{catalog}, $config->{schema}, $table_name);
}

sub identifier_name {
    my $id_name = shift;
    return unless $id_name;
    my $config = App::DB::Migrate::Config::config;
    return get_dbh()->quote_identifier($id_name);
}

sub table_from_column {
    (my $column = shift) =~ s/_+/ /g;
    (my $plural = noun($column)->plural) =~ s/\s+/_/g;
    return $plural;
}

sub join_elems { scalar(@_)? join(' ', grep { defined($_) &&  length($_ // '') } @_) : '' }

return 1;
