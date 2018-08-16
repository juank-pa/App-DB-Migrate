package Migrate::Factory;

use strict;
use warnings;

BEGIN {
    use Exporter;
    our @ISA = qw{Exporter};
    our @EXPORT_OK = qw(class create column id reference timestamp table table_index null default datatype foreign_key handler id_column primary_key handler_manager);
}

use Module::Load;
use Migrate::Config;

sub class_name { 'Migrate::'.Migrate::Config::driver()."::\u$_[0]" }

sub class {
    my $class = shift;

    my $qualified_class = class_name($class);
    eval{ load $qualified_class };

    my $error_path = join('/', split('::', $qualified_class));
    die $@ if $@ && $@ !~ /^Can't locate $error_path\.pm/;

    return $qualified_class unless $@;

    eval{ load "Migrate::\u$class" };
    die $@ if $@;
    return "Migrate::\u$class";
}

sub create { class(shift)->new(@_) }

sub id { create('identifier', @_) }
sub column { create('column', @_) }
sub reference { create('Column::References', @_) }
sub timestamp { create('Column::Timestamp', @_) }
sub id_column { create('Column::PrimaryKey', @_) }
sub table { create('table', @_) }
sub table_index { create('index', @_) }
sub datatype { create('datatype', @_) }

sub null { create('Constraint::Null', @_) }
sub default { create('Constraint::Default', @_) }
sub foreign_key { create('Constraint::ForeignKey', @_) }
sub primary_key { create('Constraint::PrimaryKey', @_) }
sub handler { create('handler', @_) }
sub handler_manager { create('Handler::Manager', @_) }

return 1;
