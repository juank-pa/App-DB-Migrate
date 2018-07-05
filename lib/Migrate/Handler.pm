package Migrate::Handler;

use strict;
use warnings;

use Lingua::EN::Inflect qw{PL};
use Migrate::Config;
use Migrate::SQLite::Handler;
use Migrate::Dbh qw{get_dbh};
use DBI;

use feature 'switch';

our $instance;
my $driver;

sub get_handler { handler_subclass()->_new }
sub _new {
    bless { sql => [] }, shift;
}

sub singleton {
    my $self = shift;
    $instance = $self->get_handler if !$instance;
    return $instance;
}

sub driver {
    my $config = Migrate::Config::config();
    (undef, $driver) = DBI->parse_dsn($config->{dsn}) if !defined($driver);
    return $driver;
}

sub migrations_table_name { shift->table_name('_migrations') }

sub table_name {
    my (undef, $table_name) = @_;
    my $config = Migrate::Config::config;
    return get_dbh()->quote_identifier($config->{catalog}, $config->{schema}, $table_name);
}

sub is_valid_datatype { exists($_[0]->datatypes()->{$_[1]}) }

sub handler_subclass { 'Migrate::'.driver().'::Handler' }
sub run_as_subclass { no strict 'refs'; &{handler_subclass().'::'.shift(@_)}() }

sub create_migrations_table_sql { shift->singleton->create_migrations_table_sql }
sub select_migrations_sql { shift->singleton->select_migrations_sql }
sub insert_migration_sql { shift->singleton->insert_migration_sql }
sub delete_migration_sql { shift->singleton->delete_migration_sql }


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
    $table->_pk_column($field_name, { index => $self->create_index_for_pk, null => 0 });

    $sub->($table);

    # create table sql
    my @columns = map { $_->{str} } @{$table->{columns}};
    $self->push_sql(qq{CREATE TABLE $plural_name(}.join(',', @columns).')', @{$table->{defaults}});

    # create indices
    my @indices = grep { $_->{unique} || $_->{index} } @{$table->{columns}};
    $self->create_index($name, $_->{name}, $_->{unique}) foreach @indices;
}

sub do { shift->push_sql(@_) }

sub should_quote {
    my ($self, $datatype) = @_;
    foreach ($self->quoted_types) {
        return 1 if $_ eq $datatype;
    }
    return 0;
}

sub quote {
    my ($self, $value) = @_;
    my $datatype = shift // $self->default_datatype;
    return get_dbh()->quote($value) if $self->should_quote($datatype);
    return $value;
}

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
    my $datatype = $self->datatypes->{shift(@_) // $self->default_datatype};
    $datatype.$self->build_datatype_attrs(@_)
}

sub build_datatype_attrs {
    my $self = shift;
    my ($m, $d) = (shift, shift);
    defined $m? '('.join(',', grep { defined $_ } ($m, $d)).')' : ''
}

return 1;
