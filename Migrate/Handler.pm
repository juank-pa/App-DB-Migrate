package Migrate::Handler;

use strict;
use warnings;

use Lingua::EN::Inflect qw{PL};
use Dbh;
use DBI;

use feature 'switch';

sub get_handler
{
    my $dsn = $Dbh::DBDataSource;
    my (undef, $driver) = DBI->parse_dsn($dsn);
    return "Migrate::${driver}::Handler"->new;
}

sub new { return bless { sql => [] }, shift }

sub push_sql
{
    my ($self, $sql, @values) = (shift, shift, @_); push @{$self->{sql}}, [$sql, \@values]
}

sub create_table
{
    my $self = shift;
    my $name = shift;
    my $sub = shift;
    (my $class = ref($self) || $self) =~ s/Handler/Table/;
    my $table = $class->new($self);
    my $plural_name = plural($name);
    my $field_name = "${name}_id";

    # Add primary key
    $table->add_column($field_name, $self->pk_datatype, { null => 0, unique => 1 });

    $sub->($table);

    # create table sql
    my @columns = map { $_->{str} } @{$table->{columns}};
    $self->push_sql(qq{CREATE TABLE "$Dbh::DBSchema".$plural_name(}.join(',', @columns).')', @{$table->{defaults}});

    # create indices
    my @indices = grep { $_->{unique} || $_->{index} } @{$table->{columns}};
    $self->create_index($name, $_->{name}, $_->{unique}) foreach @indices;

    #primary key
    $self->add_primary_key($plural_name, $field_name);
}

sub drop_table
{
    my ($self, $name) = (shift, shift);
    my $plural_name = plural($name);
    $self->push_sql("DROP TABLE $plural_name");
}

sub add_primary_key
{
    my $self = shift;
    my $table_name = shift;
    my $field_name = shift;
    $self->push_sql(qq{ALTER TABLE "$Dbh::DBSchema".$table_name ADD CONSTRAINT PRIMARY KEY (${field_name}) CONSTRAINT "$Dbh::DBSchema".pk_$table_name});
}

sub create_index
{
    my $self = shift;
    my $name = plural(shift);
    my $column = shift;
    my $unique = (shift)? 'UNIQUE ' : '';
    $self->push_sql(qq{CREATE ${unique}INDEX \"$Dbh::DBSchema".idx_${name}_${column} ON $name (${column})});
}

sub drop_index
{
    my $self = shift;
    my $name = plural(shift);
    my $column = shift;
    $self->push_sql(qq{DROP INDEX \"$Dbh::DBSchema".idx_${name}_${column}});
}

sub add_foreign_key
{
    my ($self, $source, $target) = (shift, shift, shift);
    my $source_table = plural($source);
    my $target_table = plural($target);
    my $field_name = "${target}_id";
    $self->push_sql(qq{ALTER TABLE "$Dbh::DBSchema".$source_table ADD CONSTRAINT (FOREIGN KEY ($field_name) REFERENCES $target_table($field_name) CONSTRAINT "$Dbh::DBSchema".fk_${source_table}_$field_name)});
}

sub do { shift->push_sql(@_) }

sub plural
{
    (my $table_name = shift) =~ s/_+/ /g;
    $table_name = PL($table_name);
    $table_name =~ s/\s+/_/g;
    return $table_name;
}

sub build_datatype
{
    my $self = shift;
    my $datatype = shift // $self->default_datatype;
    "$datatype".$self->build_datatype_attrs(@_)
}

sub build_datatype_attrs
{
    my $self = shift;
    my ($m, $d) = (shift, shift);
    defined $m? '('.join(',', grep { defined $_ } ($m, $d)).')' : ''
}

sub null {}

sub date {
}

sub not_null { 'NOT NULL'; }

return 1;
