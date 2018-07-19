package Migrate::Column::References;

use strict;
use warnings;

use Lingua::EN::Inflexion qw(noun verb);

use Migrate::Factory qw(create class);
use Migrate::Util;

use parent qw(Migrate::Column);

sub new {
    my ($class, $table_name, $ref_name, $options) = @_;
    $options //= {};
    die("Reference name is needed\n") if !$ref_name;
    my $id_name = "${ref_name}_id";

    my $col = bless($class->SUPER::new($id_name, $options->{type} || 'integer', $options), $class);
    $col->{table} = $table_name || die("Table name is needed\n");
    $col->{raw_name} = $ref_name;
    $col->_add_foreign_key();
    return $col;
}

sub foreign_key_data { $_[0]->{options}->{foreign_key} }
sub table { $_[0]->{table} }
sub raw_name { $_[0]->{raw_name} }

sub _add_foreign_key {
    my $self = shift;
    my $foreign_key = $self->foreign_key_data;
    return unless $foreign_key;

    $foreign_key = ref($foreign_key) eq 'HASH'? $foreign_key : {};
    my $to_table = delete($foreign_key->{to_table}) || $self->_get_table_from_column;
    $self->add_constraint(create('Constraint::ForeignKey', $self->table, $to_table, $foreign_key));
}

sub _get_table_from_column {
    my $self = shift;
    (my $column = $self->raw_name) =~ s/_+/ /g;
    (my $plural = noun($column)->plural) =~ s/\s+/_/g;
    return $plural;
}


return 1;
