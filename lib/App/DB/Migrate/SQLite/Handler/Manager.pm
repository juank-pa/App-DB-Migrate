package App::DB::Migrate::SQLite::Handler::Manager;

use strict;
use warnings;

use parent qw(App::DB::Migrate::Handler::Manager);

sub startup {
    my $self = shift;
    $self->dbh->do('PRAGMA foreign_keys=off') if $self->{enable_fk} = $self->_foreign_keys_enabled();
    $self->SUPER::startup();
}

sub run_function {
    my ($self, $code, $handler) = @_;
    $self->SUPER::run_function($code, $handler);
    $handler->flush();
    $self->_check_foreign_keys if $self->{enable_fk};
}

sub shutdown {
    my $self = shift;
    $self->SUPER::shutdown();
    $self->dbh->do('PRAGMA foreign_keys=on') if delete $self->{enable_fk};
}

sub _foreign_keys_enabled { $_[0]->dbh->selectall_arrayref('PRAGMA foreign_keys')->[0]->[0] }

sub _check_foreign_keys {
    my $self = shift;
    my $checks = $self->dbh->selectall_arrayref('PRAGMA foreign_key_check');
    if (scalar @$checks) {
        $self->dbh->rollback();
        my %errors = map { ("$_->[0] -> $_->[2]" => 1) } (@$checks);
        die ('Reference errors: '.join(', ', keys %errors));
    }
}

return 1;
