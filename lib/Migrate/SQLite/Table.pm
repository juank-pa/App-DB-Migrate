package Migrate::SQLite::Table;

use Migrate::Table;
use Migrate::Informix::Handler;

our @ISA = qw(Migrate::Table);

sub add_pk_column
{
    my $self = shift;
    my $name = shift;
    my $mh = $self->{handler};
    my $datatype = $mh->pk_datatype;

    $options->{name} = $name;
    $options->{index} = $mh->create_index_for_pk;
    $options->{str} = $self->column_str($name, $datatype).' PRIMARY KEY AUTOINCREMENT';
    push(@{$self->{columns}}, $options);
}

return 1;
