package Migrate::Handler;

use strict;
use warnings;

use Lingua::EN::Inflect qw{PL};
use Migrate::Config;
use Migrate::SQLite::Handler;
use DBI;

use feature 'switch';

our $driver;

sub get_handler { handler_subclass()->new }
sub new { return bless { sql => [] }, shift }

sub driver {
    my $config = Migrate::Config::config();
    (undef, $driver) = DBI->parse_dsn($config->{dsn}) if !defined($driver);
    return $driver;
}

sub handler_subclass { 'Migrate::'.driver().'::Handler' }
sub run_as_subclass { no strict 'refs'; &{handler_subclass().'::'.shift(@_)}() }

sub create_migrations_table_query { run_as_subclass('create_migrations_table_query') }
sub select_migrations_query { run_as_subclass('select_migrations_query') }

sub push_sql { push @{$_[0]->{sql}}, $_[1] }

sub create_table {
    my $self = shift;
    my $name = shift;
    my $sub = shift;
    (my $class = ref($self) || $self) =~ s/Handler/Table/;
    my $plural_name = $self->plural($name);
    my $table = $class->new($plural_name, $self);
    my $field_name = "${name}_id";

    # Add primary key
    $table->add_pk_column($field_name, { index => $self->create_index_for_pk, null => 0 });

    $sub->($table);

    # create table sql
    my @columns = map { $_->{str} } @{$table->{columns}};
    $self->push_sql(qq{CREATE TABLE $Dbh::DBSchema$plural_name(}.join(',', @columns).')', @{$table->{defaults}});

    # create indices
    my @indices = grep { $_->{unique} || $_->{index} } @{$table->{columns}};
    $self->create_index($name, $_->{name}, $_->{unique}) foreach @indices;

    #primary key
    $self->add_primary_key($plural_name, $field_name);
}

sub do { shift->push_sql(@_) }

sub plural {
    my $self = shift;
    (my $table_name = shift) =~ s/_+/ /g;
    $table_name = PL($table_name);
    $table_name =~ s/\s+/_/g;
    return $table_name;
}

sub unique {
    my ($self, $unique) = (shift, shift);
    return $unique? 'UNIQUE ' : '';
}

sub drop_table {
    my ($self, $name) = (shift, shift);
    my $plural_name = $self->plural($name);
    $self->push_sql("DROP TABLE $Dbh::DBSchema$plural_name");
}

sub drop_index {
    my $self = shift;
    my $name = $self->plural(shift);
    my $column = shift;
    $self->push_sql("DROP INDEX ${Dbh::DBSchema}idx_${name}_${column}");
}

sub build_datatype {
    my $self = shift;
    my $datatype = shift // $self->default_datatype;
    "$datatype".$self->build_datatype_attrs(@_)
}

sub build_datatype_attrs {
    my $self = shift;
    my ($m, $d) = (shift, shift);
    defined $m? '('.join(',', grep { defined $_ } ($m, $d)).')' : ''
}

return 1;
