#!/usr/bin/perl -w

use Mojolicious::Lite;

use strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use DBI;

use db;
use utils;
use config;

my @ARGS = @ARGV;
my ( $app_port ) = ( grep { $_ =~ /^\d+$/ } @ARGS );

my $dbh = db::connect();

sub authorize {
    my ( $self, $action ) = ( @_ );

    my $auth = $self->req->headers->authorization;

    my $auth_checked = 0;
    # какой-то код на авторизацию
    $auth_checked = 1;

    if ( $auth_checked ) {
        return &$action( $self );
    } else {
        my $headers = Mojo::Headers->new;
        $headers->add( 'WWW-Authenticate' => 'Basic' );
        $self->res->content->headers( $headers );
        $self->render( text => 'need auth', status => 401 );
    };
}

get '/test' => sub {
    my $self = shift;

    authorize( $self, sub {
        $_[0]->render( template => 'test', header => undef(), rows => undef(), email => undef() );
    } );
};

post '/test' => sub {
    my $self = shift;

    authorize( $self, sub {
        my $self = shift;
        my $email = $self->param('email');

        $email =~ tr/A-Z/a-z/;

        # можно было бы валидировать адрес, а можно и нет :)
        my $header = 'нет такого адреса';
        my $rows = $dbh->selectall_arrayref(
            'WITH ids AS (
                SELECT "int_id" FROM "log" WHERE "email" = ? GROUP BY "int_id"
            ),
            united AS (
                SELECT "ids"."int_id", "created", "str" FROM "message" INNER JOIN "ids" ON "ids"."int_id" = "message"."int_id"
                UNION
                SELECT "ids"."int_id", "created", "str" FROM "log" INNER JOIN "ids" ON "ids"."int_id" = "log"."int_id"
            )
            SELECT "united".*, COUNT(*) OVER() AS "total_count" FROM "united" ORDER BY "int_id", "created" LIMIT ?
            ', { Slice => {} }, $email, $config->{show_limit}
        );

        if ( scalar( @$rows ) ) {
            $header = undef();
            $header = 'записей более '.$config->{show_limit}.' ('.$rows->[0]->{total_count}.')' if $rows->[0]->{total_count} > $config->{show_limit};
        };

        $self->render( template => 'test', header => $header, rows => $rows, email => $email );
    } );
};

app->mode('production');
$app_port = 9000 unless $app_port;
app->start( 'daemon', 'prefork', '--clients', '100', '--listen', 'http://0.0.0.0:'.$app_port, );

exit(0);

1;

__DATA__
@@ test.html.ep
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf8">
        <title>Log Search</title>
    </head>
    <body>
        <form method="post">
            <input type="text" value="<%= $email if defined $email %>" placeholder="enter E-mail for search the logs" name="email"><br/>
            <input type="submit" value="Поиск">
        </form>
        <br/><br/>
        <hr/>
        % if ( defined $header ) {
            <div style="background-color:#FFd0d0; color:#000;"><%== $header %></div>
        % }
        % if ( defined $rows && scalar @$rows ) {
            <table>
                <tr>
                    <th>created</th>
                    <th>int_id</th>
                    <th>str</th>
                </tr>
                % my $i = 0;
                % my $last_id = '';
                % for my $row ( @$rows ) {
                %   $i++ if $row->{int_id} ne $last_id;
                %   $last_id = $row->{int_id};
                %   $i = 1 if $i > 3;
                    <tr style="background-color:#<%== $i == 1 ? 'fff' : ( $i == 2 ? 'd0d0ff' : 'ddd' ) %>;">
                        <td><%== $row->{created} %></td>
                        <td><%== $row->{int_id} %></td>
                        <td><%== $row->{str} %></td>
                    </tr>
                % }
            </table>
        % }
    </body>
</html>