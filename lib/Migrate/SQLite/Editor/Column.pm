package Migrate::SQLite::Editor::Column;

use strict;
use warnings;

use feature 'say';

use parent qw(Migrate::SQLizable);

use Migrate::SQLite::Editor::Util qw(trim);
use Migrate::SQLite::Editor::Parser qw(parse_constraint);
use Migrate::Factory qw(create class);
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

sub datatype { $_[0]->{datatype} }
sub constraints { $_[0]->{constraints} }

sub change_datatype {
    my ($self, $datatype, $options) = @_;
    my $prev_datatype = $self->datatype;
    my $datatype_obj = create('datatype', $datatype, $options);
    return if $datatype eq $prev_datatype->name && $datatype_obj->build_attrs() eq $prev_datatype->attrs_sql;

    $self->{datatype} = parse_datatype($datatype_obj);
    return 1;
}

sub is_null { !grep { ref($_) && $_->type =~ /^not null$/i } @{ shift->{constraints} } }

sub change_null {
    my ($self, $null) = @_;
    my $is_null = $self->is_null;
    return if !!$is_null == !!$null;

    if ($null) { $_->{constraints} = grep { $_->type !~ /^not null$/i } @{ $self->{constraints} }  }
    else { push @{ $self->{constraints} }, parse_constraint('NOT NULL') }
    return 1;
}

sub default { grep { ref($_) && $_->type =~ /^default$/i } @{ shift->{constraints} } }

sub change_default {
    my ($self, $default) = @_;
    my $prev_default = $self->default;
    return if !$prev_default && !defined($default);

    my $datatype = create('datatype', $self->datatype || 'string');
    my $default_obj = create('Constraint::Default', $default, { type => $datatype });
    if ($prev_default) {
        if (defined $default) { $self->_update_default($prev_default, $default_obj) }
        else { $self->_remove_default() }
    }
    else { $self->_add_default($default_obj) }
    return 1;
}

sub _remove_default { grep { ref($_) && $_->type !~ /^default$/i } @{ shift->{constraints} } }

sub _update_default {
    my ($self, $prev_default, $new_default) = @_;
    $prev_default->set_predicate([$new_default->_quoted_default_value]);
}

sub _add_default {
    my ($self, $default) = @_;
    push @{ $self->{constraints} }, parse_constraint($default);
}

sub has_fk { return grep { ref($_) && $_->type =~ /^references$/i } @{ shift->{constraints} } }

sub add_foreign_key {
    my ($self, $from, $to, $options) = @_;
    return if $self->has_fk;
    my $fk_obj = create('Constraint::ForeignKey', $from, $to, $options);
    push @{ $self->{constraints} }, parse_constraint($fk_obj);
    return 1;
}

sub remove_foreign_key { return grep { ref($_) && $_->type !~ /^references$/i } @{ shift->{constraints} } }

sub to_sql {
    my $self = shift;
    my @elems = ($self->quoted_name, $self->datatype, @{ $self->constraints });
    return Migrate::Util::join_elems(@elems);
}

return 1;
