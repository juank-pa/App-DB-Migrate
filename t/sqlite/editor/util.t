use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;

use App::DB::Migrate::SQLite::Editor::Util;

subtest 'trim removes surrounding white space' => sub {
    is(App::DB::Migrate::SQLite::Editor::Util::trim("\t\n  test \n "), 'test');
};

subtest 'trim supports undefined values' => sub {
    is(App::DB::Migrate::SQLite::Editor::Util::trim(undef), undef);
};

subtest 'trim supports undefined values' => sub {
    is(App::DB::Migrate::SQLite::Editor::Util::trim(undef), undef);
};

subtest 'unquotes removes double quotes' => sub {
    is(App::DB::Migrate::SQLite::Editor::Util::unquote('"quoted"'), 'quoted');
};

subtest 'unquotes unescapes internal quotes' => sub {
    is(App::DB::Migrate::SQLite::Editor::Util::unquote('"quo""ted"'), 'quo"ted');
};

subtest 'unquotes supports undef values' => sub {
    is(App::DB::Migrate::SQLite::Editor::Util::unquote(undef), undef);
};

done_testing();
