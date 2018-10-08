package App::DB::Migrate::Handler::Manager;

use strict;
use warnings;

use App::DB::Migrate::Dbh qw(get_dbh);
use App::DB::Migrate::Factory qw(class handler);

sub new {
    my ($class, $dry, $output, $dbh) = @_;
    return bless { dry => $dry, output => $output, dbh => $dbh }, $class;
}

sub startup {
    my $self = shift;
    $self->dbh->begin_work;
}

sub dbh { shift->{dbh} // get_dbh }

sub execute {
    my $self = shift;
    my $code = shift // die('Code needed');
    my $migration_id = shift // die('Migration id needed');
    my $direction = shift // 'up';

    $self->startup();

    eval {
        $self->run_function($code, $self->get_handler);
        $self->record_migration($direction, $migration_id) unless $self->{dry};
    };

    $self->shutdown();
}

sub shutdown {
    my $self = shift;
    my $error = $@;
    return $self->dbh->commit unless $error;
    $self->dbh->rollback;
    die($error);
}

sub get_handler { my $self = shift; handler($self->{dry}, $self->{output}, $self->dbh) }

sub run_function {
    my ($self, $code, $handler) = @_;
    $code->($handler);
}

sub record_migration {
    my ($self, $direction, $id) = @_;
    my $sql = $direction eq 'up'
        ? class('migrations')->insert_migration_sql
        : class('migrations')->delete_migration_sql;
    $self->dbh->prepare($sql)->execute($id) or die("Error recording migration data ($direction)");
}

return 1;
