package Migrate::Datatype;

use strict;
use warnings;

use Migrate::Handler;
use Scalar::Util qw(weaken);
use Migrate::Dbh qw{get_dbh};

use overload
    fallback => 1,
    '""' => \&to_sql;

# Static methods
sub new {
    my ($class, $name, $options) = @_;
    my $data = {
        name => $name || $class->default_datatype,
        options => $options };

    die("Invalid datatype: $name\n") if !$class->is_valid_datatype($data->{name});
    return bless($data, $class);
}

sub quoted_datatypes { qw{string char text date time datetime} }
sub timestamp_datatypes { qw{date time datetime} }
sub default_datatype { 'string' }

sub is_valid_datatype { $_[1] && exists($_[0]->datatypes()->{$_[1]}) }
sub is_timestamp_datatype { grep /$_[0]/, @{ $_[0]->timestamp_datatypes } }

sub datatypes { {} } #Implement in subclass

sub _should_quote {
    my ($class, $name) = @_;
    foreach ($class->quoted_datatypes) {
        return 1 if $_ eq $name;
    }
    return 0;
}

# Instance methods

sub name { $_[0]->{name} }
sub native_name { $_[0]->datatypes->{$_[0]->{name}} }
sub limit { $_[0]->{options}{limit} }
sub precision { $_[0]->{options}{precision} }
sub scale { $_[0]->{options}{scale} }

sub quote {
    my ($self, $value) = @_;
    return get_dbh()->quote($value) if $self->_should_quote($self->name);
    return $value;
}

sub to_sql {
    my $self = shift;
    $self->native_name.$self->_build_datatype_attrs();
}

sub _build_datatype_attrs {
    my $self = shift;
    my ($m, $d) = ($self->precision // $self->limit, $self->scale);
    defined $m? '('.join(',', grep { defined $_ } ($m, $d)).')' : ''
}

return 1;
