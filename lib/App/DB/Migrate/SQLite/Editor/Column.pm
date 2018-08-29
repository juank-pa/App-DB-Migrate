package App::DB::Migrate::SQLite::Editor::Column;

use strict;
use warnings;

use parent qw(App::DB::Migrate::SQLizable);

use App::DB::Migrate::SQLite::Editor::Util qw(trim);
use App::DB::Migrate::SQLite::Editor::Parser qw(parse_constraint);
use App::DB::Migrate::SQLite::Editor::Datatype;
use App::DB::Migrate::Factory qw(datatype default id);
use App::DB::Migrate::Util;

sub new {
    my ($class, $name, $datatype, @constraints) = @_;
    my $data = {
        name => $name || die('Column name needed'),
        datatype => $datatype || App::DB::Migrate::SQLite::Editor::Datatype->new,
        constraints => [@constraints]
    };
    return bless $data, $class;
}

sub name { $_[0]->{name} }

sub rename {
    my ($self, $to) = @_;
    $self->{name} = $to || die('Column name needed');
}

sub type { $_[0]->{datatype} }
sub constraints { $_[0]->{constraints} }

sub is_null { !$_[0]->_select_constraint('not null') }

sub change_null {
    my ($self, $null) = @_;
    my $is_null = $self->is_null;
    return if $is_null == !!$null;

    if ($null) { $self->_remove_constraint('not null') }
    else {
        $self->_remove_constraint('null');
        push @{ $self->{constraints} }, parse_constraint('NOT NULL')
    }
    return 1;
}

sub _select_constraint {
    my ($self, $type) = @_;
    return grep { _is_constraint_typed($_, $type) } @{ $self->{constraints} };
}

sub _remove_constraint {
    my ($self, $type) = @_;
    $self->{constraints} = [ grep { !_is_constraint_typed($_, $type) } @{ $self->{constraints} } ];
}

sub _is_constraint_typed {
    my ($constraint, $type) = @_;
    return ref($constraint) && $constraint->type =~ /^$type$/i
}

sub default_constraint { ($_[0]->_select_constraint('default'))[0] }

sub change_default {
    my ($self, $default) = @_;
    my $prev_default = $self->default_constraint;
    return if !$prev_default && !defined($default);

    my $default_obj = default($default, { type => datatype($self->type->name) });
    if ($prev_default) {
        if (defined $default) { $self->_update_default($prev_default, $default_obj) }
        else { $self->_remove_constraint('default') }
    }
    else { $self->_add_default($default_obj) }
    return 1;
}

sub _update_default {
    my ($self, $prev_default, $new_default) = @_;
    $prev_default->set_predicate($new_default->quoted_default_value);
}

sub _add_default {
    my ($self, $default) = @_;
    push @{ $self->{constraints} }, parse_constraint($default->to_sql);
}

sub foreign_key_constraint { ($_[0]->_select_constraint('references'))[0] }

sub add_foreign_key {
    my ($self, $fk) = @_;
    return if $self->foreign_key_constraint;
    my $constraint = parse_constraint($fk);
    die('Invalid foreign key') if !$constraint || !ref($constraint) || $constraint->type !~ /references/i;
    push @{ $self->{constraints} }, $constraint;
    return 1;
}

sub remove_foreign_key { $_[0]->_remove_constraint('references') }

sub has_constraint_named {
    my ($self, $name) = @_;
    return grep { _is_constraint_named($_, $name) } @{ $self->{constraints} };
}

sub _is_constraint_named {
    my ($constraint, $name) = @_;
    return ref($constraint) && $constraint->name =~ /^$name$/i
}

sub to_sql {
    my $self = shift;
    my @elems = (id($self->name), $self->type, @{ $self->constraints });
    return App::DB::Migrate::Util::join_elems(@elems);
}

return 1;
