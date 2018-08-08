package Migrate::SQLite::Editor::Column;

use strict;
use warnings;

use parent qw(Migrate::SQLizable);

use Migrate::SQLite::Editor::Util qw(trim);
use Migrate::SQLite::Editor::Parser qw(parse_constraint parse_datatype);
use Migrate::SQLite::Editor::Datatype;
use Migrate::Factory qw(create class foreign_key datatype);
use Migrate::Util;

sub new {
    my ($class, $name, $datatype, @constraints) = @_;
    my $data = { name => $name, datatype => $datatype, constraints => [@constraints] };
    return bless $data, $class;
}

sub name { $_[0]->{name} }
sub quoted_name { (my $name = $_[0]->name) =~s/"/""/g; qq{"$name"}  }

sub rename {
    my ($self, $to) = @_;
    $self->{name} = $to;
}

sub type { $_[0]->{datatype} }
sub constraints { $_[0]->{constraints} }

sub change_datatype {
    my ($self, $datatype, $options) = @_;
    my $prev_datatype = $self->type;
    my $datatype_obj = datatype($datatype, $options);
    return if $datatype eq $prev_datatype->name && $datatype_obj->build_attrs() eq $prev_datatype->attrs_sql;

    $self->{datatype} = parse_datatype($datatype_obj);
    return 1;
}

sub is_null { !$_[0]->_select_constraint('not null') }

sub change_null {
    my ($self, $null) = @_;
    my $is_null = $self->is_null;
    return if !!$is_null == !!$null;

    if ($null) { $self->_remove_constraint('not null') }
    else { push @{ $self->{constraints} }, parse_constraint('NOT NULL') }
    return 1;
}

sub _select_constraint {
    my ($self, $name) = @_;
    return grep { _is_constraint($_, $name) } @{ $self->{constraints} };
}

sub _remove_constraint {
    my ($self, $name) = @_;
    $self->{constraints} = [ grep { !_is_constraint($_, $name) } @{ $self->{constraints} } ];
}

sub _is_constraint {
    my ($constraint, $name) = @_;
    return ref($constraint) && $constraint->type =~ /^$name$/i
}

sub default { $_[0]->_select_constraint('default') }

sub change_default {
    my ($self, $default) = @_;
    my $prev_default = $self->default;
    return if !$prev_default && !defined($default);

    my $datatype = datatype($Migrate::SQLite::Editor::Datatype::datatypes{$self->type // ''} || 'string');
    my $default_obj = $self->default($default, { type => $datatype });
    if ($prev_default) {
        if (defined $default) { $self->_update_default($prev_default, $default_obj) }
        else { $self->_remove_constraint('default') }
    }
    else { $self->_add_default($default_obj) }
    return 1;
}

sub _update_default {
    my ($self, $prev_default, $new_default) = @_;
    $prev_default->set_predicate([$new_default->_quoted_default_value]);
}

sub _add_default {
    my ($self, $default) = @_;
    push @{ $self->{constraints} }, parse_constraint($default);
}

sub has_foreign_key { $_[0]->_select_constraint('references') }

sub foreign_key_constraint { ($_[0]->has_foreign_key)[0] }

sub add_foreign_key {
    my ($self, $fk) = @_;
    return if $self->has_foreign_key;
    push @{ $self->{constraints} }, parse_constraint($fk);
    return 1;
}

sub remove_foreign_key { $_[0]->_remove_constraint('references') }

sub to_sql {
    my $self = shift;
    my @elems = ($self->quoted_name, $self->type, @{ $self->constraints });
    return Migrate::Util::join_elems(@elems);
}

return 1;
