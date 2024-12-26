package db;

use DBI;

use config;
use utils;

our $dbh;

sub connect {
    my $success = eval {
        $dbh = DBI->connect('dbi:Pg:dbname='.$config->{DB}->{dbname}.';host='.$config->{DB}->{host}.';port='.$config->{DB}->{port}, $config->{DB}->{user}, $config->{DB}->{password}, {AutoCommit=>1,RaiseError=>1,PrintError=>0});

        return 1;
    };
    err( "Unable to connect to DB $@" ) if !$success || !$dbh;

    return $dbh;
}

sub DESTROY {
    $dbh->disconnect() if $dbh;
}

1;