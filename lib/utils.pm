package utils;

use config;

use POSIX qw();
use Data::Dumper;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT    = qw(log err dump);
our @EXPORT_OK = (@EXPORT,);

our $log_separator = "\t";

sub log {
    print STDERR POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime time).$config->{log_cols_separator}.join( $config->{log_line_separator}, @_ )."\n";
}

sub err {
    &log( @_ );
    exit( 1 );
}

sub dump {
    my $body = (caller(1))[3];
    my $msg = ( $body ? $body:'main').':'.(caller(0))[2].$config->{log_cols_separator};
    $msg .= join( ', ', 
        map {
            ref $_ ? Data::Dumper->new( [ $_ ] )->Indent( 1 )->Pair( ' => ' )->Terse( 1 )->Sortkeys( 1 )->Dump()
                :
                defined( $_ ) ? "'$_'" : 'undef'
        }
        @_
    );
    $msg .= $config->{log_line_separator};
    &log( $msg );
}

1;