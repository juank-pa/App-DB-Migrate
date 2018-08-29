package App::DB::Migrate::Column::References;

use strict;
use warnings;


use App::DB::Migrate::Factory qw(foreign_key column);
use App::DB::Migrate::Util;

use parent qw(App::DB::Migrate::SQLizable);

# TODO:
# * Add support to 'polymorphic' references.

sub new {
    my ($class, $table_name, $ref_name, $options) = @_;
    $options //= {};
    $options->{index} //= 1;
    $table_name || die('Table name is needed');
    $ref_name || die('Reference name is needed');

    my $id_name = (ref($options->{foreign_key}) eq 'HASH' && $options->{foreign_key}->{column}) || "${ref_name}_id";

    my $col = column($id_name, $options->{type} || 'integer', $options);
    my $fk = $class->_get_fk($table_name, $ref_name, $options);
    $col->add_constraint($fk) if $fk;
    return bless { table => $table_name, column => $col, fk => $fk, raw_name => $ref_name }, $class;
}

# Delegates
sub name { $_[0]->{column}->name }
sub options { $_[0]->{column}->options }
sub type { $_[0]->{column}->type }
sub constraints { $_[0]->{column}->constraints }
sub index { $_[0]->{column}->index }
sub to_sql { $_[0]->{column}->to_sql }

sub foreign_key_constraint { $_[0]->{fk} }
sub table { $_[0]->{table} }
sub raw_name { $_[0]->{raw_name} }

sub _get_fk {
    my ($class, $table_name, $ref_name, $options) = @_;
    my $fk_options = $options->{foreign_key};
    return unless $fk_options;

    $fk_options = ref($fk_options) eq 'HASH'? $fk_options : {};
    my $to_table = $fk_options->{to_table} || App::DB::Migrate::Util::table_from_column($ref_name);
    return foreign_key($table_name, $to_table, $fk_options);
}

return 1;
