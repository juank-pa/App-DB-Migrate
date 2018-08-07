package Migrate::SQLite::Handler;

use strict;
use warnings;

use parent qw(Migrate::Handler);

use Migrate::SQLite::Editor;

sub editor_for {
    my ($self, $table_name) = @_;
    $self->flush() if $self->has_editor && $self->editor->name ne $table_name;
    $self->{editor} = Migrate::SQLite::Editor::edit_table($table_name) unless defined($self->editor);
    return $self->editor;
}

sub has_editor_for { $_[0]->editor && $_[0]->editor->name eq $_[1] }

sub editor { $_[0]->{editor} }

sub flush {
    my $self = shift;
    $self->execute($self->editor->to_sql) if defined $self->editor && $self->editor->has_changed;
    delete $self->{editor};
    return $self;
}

sub create_table { my $self = shift; $self->flush()->SUPER::create_table(@_) }
sub drop_table { my $self = shift; $self->flush()->SUPER::drop_table(@_) }

sub add_index { my $self = shift; $self->flush()->SUPER::add_index(@_) }
sub remove_index { my $self = shift; $self->flush()->SUPER::remove_index(@_) }

sub add_raw_column {
    my ($self, $table, $column) = @_;
    return $self->flush()->SUPER::add_raw_column($table, $column) unless $self->has_editor_for($table);
    $self->editor_for($table)->add_raw_column($column);
}

sub remove_column {
    my ($self, $table, $column) = @_;
    $self->editor_for($table)->remove_columns($column);
}

sub rename_index {
    my ($self, $old_name, $new_name) = @_;
    $self->flush();
    Migrate::SQLite::Editor::rename_index($old_name, $new_name);
}

sub rename_table {
    my ($self, $old_name, $new_name) = @_;
    $self->execute($self->editor_for($old_name)->rename($new_name));
}

sub rename_column {
    my ($self, $table, $old_name, $new_name) = @_;
    $self->editor_for($table)->rename_column($old_name, $new_name);
}

sub add_foreign_key {
    my ($self, $table, $to, $options) = @_;
    $self->editor_for($table)->add_foreign_key($to, $options);
}

sub remove_foreign_key {
    my ($self, $table, $to, $options) = @_;
    $self->editor_for($table)->remove_foreign_key($to, $options);
}

sub add_reference {
    my ($self, $table, $ref_name, $options) = @_;
    $self->editor_for($table)->add_reference($ref_name, $options);
}

sub remove_reference {
    my ($self, $table, $name, $options) = @_;
    $self->editor_for($table)->remove_reference($name, $options);
}

sub add_timestamps {
    my ($self, $table, $options) = @_;
    $self->editor_for($table)->add_timestamps($options);
}

sub remove_timestamps {
    my ($self, $table) = @_;
    $self->editor_for($table)->remove_timestamps();
}

sub change_column {
    my ($self, $table, $column_name, $datatype, $options) = @_;
    $self->editor_for($table)->change_column($column_name, $datatype, $options);
}

sub change_column_default {
    my ($self, $table, $column_name, $default) = @_;
    $self->editor_for($table)->change_column_default($column_name, $default);
}

sub change_column_null {
    my ($self, $table, $column_name, $null) = @_;
    $self->editor_for($table)->change_column_default($column_name, $null);
}

return 1;
