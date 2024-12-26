package config;

our $config = {};

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT    = qw($config);
our @EXPORT_OK = (@EXPORT,);

$config->{DB} = {
    dbname      =>  'test1',
    host        =>  'localhost',
    port        =>  5432,
    user        =>  'test1',
    password    =>  'test1'
};

$config->{log_cols_separator} = "\t";
$config->{log_line_separator} = "\n";

$config->{show_limit} = 100;
$config->{push_limit} = 100;

1;