use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::Trap;
use Test::MockModule;
use Test::MockObject;
use Mocks;

use App::DB::Migrate::Handler;

subtest 'new creates a handler manager' => sub {
    my $mh = App::DB::Migrate::Handler->new();
    isa_ok($mh, 'App::DB::Migrate::Handler');
};

subtest 'imports get_dbh from App::DB::Migrate::Dbh' => sub {
    use App::DB::Migrate::Dbh;
    is(\&App::DB::Migrate::Dbh::get_dbh, \&App::DB::Migrate::Handler::get_dbh);
};

subtest 'imports factories from App::DB::Migrate::Factory' => sub {
    use App::DB::Migrate::Factory;
    my @factories = qw(column timestamp foreign_key table_index table id reference);

    for (@factories) {
        is(\&{"App::DB::Migrate::Factory::$_"}, \&{"App::DB::Migrate::Handler::$_"});
    }
};

subtest 'dbh returns the dbh given at construction' => sub {
    my $dbh = Test::MockObject->new();
    my $mh = App::DB::Migrate::Handler->new(0, undef, $dbh);
    is($mh->dbh, $dbh);
};

my $mh_mod = new Test::MockModule('App::DB::Migrate::Handler');

subtest 'dbh returns the default dbh if not given at construction' => sub {
    my $dbh = Test::MockObject->new();
    $mh_mod->redefine(get_dbh => $dbh);

    my $mh = App::DB::Migrate::Handler->new();
    is($mh->dbh, $dbh);
};

my $dbh = Test::MockObject->new;
$mh_mod->redefine(dbh => $dbh);
$dbh->{test} = 'dbh';

subtest 'execute prepares and executes the given sql list' => sub {
    my $mh = App::DB::Migrate::Handler->new();
    my @prepared_sqls;
    my @executed_sqls;
    $dbh->mock(prepare => sub {
        my $sql = $_[1];
        push @prepared_sqls, $sql;
        my $sth = Test::MockObject->new;
        $sth->mock('execute', sub { push @executed_sqls, $sql });
        return $sth;
    });

    $mh->execute(qw(SQL1 SQL2));
    is_deeply(\@prepared_sqls, [qw(SQL1 SQL2)]);
    is_deeply(\@executed_sqls, [qw(SQL1 SQL2)]);
};

subtest 'execute prints to output is one is given' => sub {
    my $mh = App::DB::Migrate::Handler->new(0, \*STDOUT);
    trap { $mh->execute(qw(SQL1 SQL2)) };
    is($trap->stdout, "SQL1;\nSQL2;\n")
};

subtest 'execute does not print if no output is given' => sub {
    my $mh = App::DB::Migrate::Handler->new(0);
    trap { $mh->execute(qw(SQL1 SQL2)) };
    is($trap->stdout, '');
};

done_testing();
