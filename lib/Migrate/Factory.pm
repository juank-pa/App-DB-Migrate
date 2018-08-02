package Migrate::Factory;

use strict;
use warnings;

BEGIN {
    use Exporter;
    our @ISA = qw{Exporter};
    our @EXPORT_OK = qw(class create);
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

return 1;
