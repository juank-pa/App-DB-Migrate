package Migrate::SQLite::Handler;

use strict;
use warnings;

use parent qw(Migrate::Handler);

#use Migrate::Factory qw(table);
use Migrate::SQLite::Editor;

sub _get_editor {
    my ($self, $table_name) = @_;
    $self->flush() if $self->editor && $self->editor->name ne $table_name;
    $self->{editor} = Migrate::SQLite::Editor::edit_table($table_name) unless defined($self->editor);
    return $self->editor;
}

sub editor { $_[0]->{editor} }

sub flush {
    my $self = shift;
    $self->push_sql($self->editor->to_sql) if defined $self->editor && $self->editor->has_changed;
    delete $self->{editor};
    return $self;
}

sub create_table { my $self = shift; $self->flush()->SUPER::create_table(@_) }
sub drop_table { my $self = shift; $self->flush()->SUPER::drop_table(@_) }

sub add_index { my $self = shift; $self->flush()->SUPER::add_index(@_) }
sub remove_index { my $self = shift; $self->flush()->SUPER::remove_index(@_) }

sub add_raw_column {
    my ($self, $table, $column) = @_;
    $self->_get_editor($table)->add_raw_column($column);
}

sub remove_column {
    my ($self, $table, $column) = @_;
    $self->_get_editor($table)->remove_columns($column);
}

sub rename_index {
    my ($self, $old_name, $new_name) = @_;
    $self->flush();
    Migrate::SQLite::Editor::rename_index($old_name, $new_name);
}

sub rename_table {
    my ($self, $old_name, $new_name) = @_;
    $self->push_sql($self->_get_editor($old_name)->rename($new_name));
}

sub rename_column {
    my ($self, $table, $old_name, $new_name) = @_;
    $self->_get_editor($table)->rename_column($old_name, $new_name);
}

sub add_foreign_key {
    my ($self, $table, $to, $options) = @_;
    $self->_get_editor($table)->add_foreign_key($to, $options);
}

sub remove_foreign_key {
    my ($self, $table, $to, $options) = @_;
    $self->_get_editor($table)->remove_foreign_key($to, $options);
}

sub add_reference {
    my ($self, $table, $ref_name, $options) = @_;
    $self->_get_editor($table)->add_reference($ref_name, $options);
}

sub remove_reference {
    my ($self, $table, $name, $options) = @_;
    $self->_get_editor($table)->remove_reference($name, $options);
}

sub add_timestamps {
    my ($self, $table, $options) = @_;
    $self->_get_editor($table)->add_timestamps($options);
}

sub remove_timestamps {
    my ($self, $table) = @_;
    $self->_get_editor($table)->remove_timestamps();
}

sub change_column {
    my ($self, $table, $column_name, $datatype, $options) = @_;
    $self->_get_editor($table)->change_column($column_name, $datatype, $options);
}

sub change_column_default {
    my ($self, $table, $column_name, $default) = @_;
    $self->_get_editor($table)->change_column_default($column_name, $default);
}

sub change_column_null {
    my ($self, $table, $column_name, $null) = @_;
    $self->_get_editor($table)->change_column_default($column_name, $null);
}

return 1;
