#!/usr/bin/perl -w

use strict;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";

use db;
use utils;

my $in = $ARGV[0];
err( "Usage:   $0 /path/to/readable/file" ) if !$in || !-e $in || !-r $in;

# поэкономим память, не будем раздувать массив записей, и будем обрабатывать каждую запись по мере прочтения, поэтому подключимся заранее.
my $dbh = db::connect();
my $enough_to_push = 100; # просто мы будем сохранять каждые 1000 записей для ускорения работы с БД, в реальности количество батч инсертов зависит от того сколько кортежей влезет в 4Гб.
my $db_lines = { log => [], message => [] };

# регэкспы для парсинга прекомпильнём заранее
my $re = {
    date    =>  qr/\d{4}\-\d{2}\-\d{2}\s\d{2}\:\d{2}\:\d{2}/,
    id      =>  qr/[a-zA-Z0-9]{6}-[a-zA-Z0-9]{6}-[a-zA-Z0-9]{2}/,
    flag    =>  qr/\<\=|\=\>|\-\>|\*\*|\=\=/,
    email   =>  qr/(?:.*?\s\<|\<)?(?:[\w\-\.]+\@(?:\w+|\-|\.)+\w+)?\>?/, # конечно я знаю про классический регэксп, его можно взять на metacpan-е, но здесь запишу простенький, к тому же в теории это уже прошло обработку почтовым сервером.
};

open( my $fh, $in ) or err( "Can't open $in for read" );
# переходим в бинмод
binmode( $fh );
# будем обрабатывать "поблочно", в логике тут может быть любое 512-кратное число ( размер блока ), обычно я вообще использую 524288 ( 512Кб ).
my $block_size = 512;
my $last_line;
my $counter = {};
while( sysread( $fh, my $buf, $block_size ) ) {
    # как альтернативу ещё можно было бы использовать CSV::XS построчно, ну да ладно )), будем считать что и вы здесь строки не квотировали.
    if ( !defined( $last_line ) ) {
        $buf =~ s/^\xEF\xBB\xBF//;
        $last_line = '';
    };
    $buf = $last_line.$buf;
    
    my $lines = [ split /\r*\n/, $buf, -1 ];
    $last_line = pop @$lines;

    &process_line( $_ ) foreach ( @$lines );
};
# файл больше не нужен
close( $fh );
# а вот последнюю строку забывать не стоит.
&process_line( $last_line, 1 );
dump $counter;

exit(0);

sub process_line($;$) { # никто не просил, просто показываю что и про это знаю..
    my ( $line, $push ) = @_;

    my $row = {};    
    if ( $line =~ /^($$re{date})\s(($$re{id})\s($$re{flag})\s($$re{email})\s.*?)$/) {
        ( $$row{created}, $$row{str}, $$row{int_id}, $$row{flag}, $$row{address} ) = @{^CAPTURE};
        if ( $$row{flag} eq '<=' ) {
            ( $$row{id} ) = ( $$row{str} =~ /id=(.*?)(?:\s|$)/ );
            # хак, т.к. прописан not null по структуре,
            $$row{id} //= '';
            push @{ $db_lines->{message} }, $row;
        } else {
            ( $$row{email} ) = ( $$row{address} =~ /^(?:.*?\s\<)?(.*?)\>?$/ );
            $$row{email} =~ tr/A-Z/a-z/ if $$row{email};
            push @{ $db_lines->{log} }, $row;
        };
    } elsif ( $line =~ /^($$re{date})\s(($$re{id})\s.*?)$/ ) {
        ( $$row{created}, $$row{str}, $$row{int_id} ) = @{^CAPTURE};
        push @{ $db_lines->{log} }, $row;
    } else {
        # тут чота нитак пошло
        $counter->{failed}++;
    }

    commit_lines( $push );
};

sub commit_lines($) {
    my ( $push ) = @_;
    my $headers = {
        log => [ qw(int_id created str address email) ],
        message => [ qw(id int_id created status str) ]
    };

    foreach my $table ( keys %$db_lines ) {
        if ( ( $push || scalar( @{ $db_lines->{$table} } ) >= $enough_to_push ) && scalar( @{ $db_lines->{$table} } ) ) {
            my $lines = $db_lines->{$table};
            $counter->{$table} += scalar( @$lines );
            my $h = $headers->{ $table };
            my $q = 'INSERT INTO "'.$table.'" ('.join( ', ', map { '"'.$_.'"' } @$h ).') VALUES '.
                    join( ', ', map { my $r = $_; '('.join( ', ', map { $dbh->quote( $r->{$_} ) } @$h ).')' } @$lines ).' ON CONFLICT DO NOTHING'; #я в курсе про плейсхолдеры, мне лень :)
            $dbh->do( $q );
            $db_lines->{$table} = [];
        }
    }
}

=pod
Уважаемые коллеги по цеху, выскажу замечания :)
1. Вы не сказали что делать со строчками которые имеют адрес вида <>, поэтому на своё усмотрение я их сохраняю с пустой строкой, по логике задачи это следовало бы не сохранять вообще, или
сохранять в отдельной таблице, - я сохраняю.
2. Вы также не уточнили следует ли извлекать только почтовый адрес, т.е. условно
- udbbwscdnbegrmloghuf@london.com - валидный адрес;
- :blackhole: <tpxmuwr@somehost.ru> - на мой взгляд в рамках постановки не валидный, однако я его также сохраняю полностью;
как итог - я добавил колонку email - чтобы искать по точному вхождению, а не по LIKE.
3. попросили бы просто запрос, зачем эти пляски с моджо.. )
4. вообще история с каунтами всегда просит триггеров, но я решил не делать, т.к. получается что - 
    - получая запись с адресом в логе - before insert в условную таблицу каунтов по емэйлу надо посчитать текущие вхождения,
    - получая запись с емэйлом - смотреть имеем ли мы такой int_id с емэйлом, и если да, то увеличивать, а если нет - то нет.
    - поскольку я счёл эти операции более медленными чем COUNT(*) OVER() - было принято решение триггеры не добавлять.
=cut