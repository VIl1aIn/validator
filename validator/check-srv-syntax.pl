#!/usr/bin/perl -w

use strict;

=encoding utf-8

=head1 скрипт проверки файлов шаблонов на орфографию

=head1 вызов так:

=head2 check-srv-syntax.pl [<имя mc файла> [<имя словаря>]]

Файл словаря ищется в текущем каталоге. Если не задан, то используется
имя B<dictionary.txt>

=head3 Сделано, ну или будет:

Проверяем только:

=over

=item -

Орфографию слов по словарю

=item -

Минимальную корректность синтаксиса

=back

=head3 Функция I<okOut>

Форматированный вывод в случае отсутствия ошибок в проверяемом файле

=cut

sub okOut {
    print "File @_ is valid\n";
    print "SUCCESSFULL\n";
}

=head3 Функция I<errOut>

Форматированный вывод трех параметров из массива @result:

=over

=item -

Номер строки где есть ошибка

=item -

Слово где есть ошибка

=item -

Целиком ошибочная строка

=back

=cut
    
sub errOut {
    our @result;
    my $ind;

    print "Check .mc file in string: \n";
    for ($ind = 0; $ind <= $#result; $ind += 3) {
	print $result[$ind].": ".$result[$ind+2];
	# parse words
	my ($fw,$lw) = split /:/,$result[$ind+1];
	print "Check word(s): '".$fw."'";
	print ", '".$lw."'" if ($lw);
	print "\n";
    }

    print "ERROR!\n"
}


=head3 Функции I<thinCheck>

Выполняет "тонкую" проверку слов по алгоритму:

Меняем символы в проверяемом слове на "@" по маске слова из
словаря. Подсчитываем кол-во совпадений. Если совпадений нет или их
меньше порога, считаем что это комментарий и ошибки нет. Иначе высока
вероятность, что это ошибка в слове.

Дополнительно проверяем длины слова и слова из словаря, чтобы
исключить реакцию на создаваемые макросы типа: B<_template_AlertKey>

=cut


# >=1 - true it is errors (many accordance)
# 0 - false it is comment (0 accord)
sub thinCheck {
    my ($checkWord, $dict) = (shift, shift);
    my $countRpl = ($checkWord =~ s/["$dict"]/@/g);
    my $thresh = int(length($dict)/2+1); # Threshold value

    # Additional check by length string more *2
    # Ex: _template_AlertKey
    return 0 if (length($checkWord)>length($dict)*2);
    
    return 0 if ($countRpl <= $thresh);
    return $countRpl/$thresh;
}


=head3 Функция I<checkComment>

Пропускает строки, не подлежащие проверке.

Сейчас это:

=over

=item -

Комментарии C<# Text>, C<dnl Comment>.

=item -

Пустые и незначимые строки

=item -

Строки, начинающиеся макросами, созданными внутри документа. По
внутреннему соглашению это строки начинающиеся с C<__> (двух
подчеркиваний).

=back

=cut

# Skip comment and empty line
# Skip word such kind: __WORD double "_"
sub checkComment {
    return /^\n$|^ *(#|dnl)|^ +$|^___*/?0:1;
}

=head3 Функция I<checkSyntax>

Получает на вход строку из файла шаблона и выполняет такие шаги:

=over

=item -

Выделяет из строки первое и последнее слово по символам "(",
")", при этом дополнительно последнюю фразу делит на слова по символам
" ". Требуется для проверки конструкции типа:

dnl Здесь текст комментария

MACROS(val1,val2,...,valN)dnl Тоже комментарии

=item -

Прогоняет слова на соответсвие словам из словаря. Если соответствия не
найдено, то использует процедуру тонкой проверки I<thinCheck>

=back

Возвращает строку:

=over

=item -

C<"OK"> если все нормально, ошибок нет

=item -

Ошибочные слово(а) в формате C<[первое слово:][последнее слово]>

=back

=cut
    
sub checkSyntax {
    our @dict;
    my ($rf,$rl,$rtf,$rtl,$maxF,$maxL) = (0,0,1,1,0,0);
    my $final = ""; # Error words
    ###############my ($dictF,$dictL) = ("",""); # DEBUG

    s/^[ \t]+//; # Delete space char
    # Check by dictionary
    my @words = split/\(|\)/;
    # Get key words
    my $firstWord = $words[0];
    my $lastWord = $words[$#words];
    chomp ($firstWord,$lastWord);

    # Additional convert last word for construction type:
    # dnl word1 word2 ... wordN
    # MACROS()dnl word1 word2 ... wordN
    # Get only first word
    my ($tmp) = split/ /,$lastWord;
    $lastWord = $tmp if ($tmp);

    # Check syntax by dictionary
  end:
    foreach my $dictWrd (@dict) {
	if (! $rf) {
	    if ($firstWord eq $dictWrd) {
		$rf = 1;
		$maxF = 0;
	    } else {
		$rtf = thinCheck($firstWord,$dictWrd);
		# Here may remember $dict for first word if needs...
		###################$dictF = $dictWrd if ($rtf > $maxF); # DEBUG
		$maxF = $rtf if ($rtf > $maxF);
	    }
	}
	if (! $rl) {
	    if ($lastWord eq $dictWrd) {
		$rl = 1;
		$maxL = 0;
	    } else {
		$rtl = thinCheck($lastWord,$dictWrd);
		# Here may remember $dict for last word if needs...
		###############$dictL = $dictWrd if ($rtl > $maxL); # DEBUG
		$maxL = $rtl if ($rtl > $maxL);
	    }
	}
	last end if ($rf && $rl); # Full accord find
    }

    return "OK" unless ($maxF || $maxL);
    $final = $firstWord if ($maxF);
    $final .= $maxF?":".$lastWord:$lastWord if ($maxL);
    #############print "DICT=".$dictF.":".$dictL."\n";
    return $final;
}


# Init section

my $nameMC = defined $ARGV[0]?$ARGV[0]:"service.mc";
my $nameDict = defined $ARGV[1]?$ARGV[1]:"dictionary.txt";
our @dict;

# Get dictionary
my $i = 0;
open(DICT,"<$nameDict") || die "Dictionary $nameDict not found";
while (<DICT>) {
    chomp;
    $dict[$i++] = $_;
}
close(DICT);

if ("$nameMC" eq "--help"|
	"$nameMC" eq "-h"|
	"$nameMC" eq "-?") {
		print <<EOF;
Usage: $0 <dictionary> <name-file.mc>
EOF
	exit 0;
}

# Open m4 service project
# Get lines
open(MC,"<$nameMC") || die "File with service template $nameMC not found";
print "Analyze begin\n---------\n";
my $numLine = 0;
our @result;
my $res;
my $ind = 0;
while(<MC>) {
    $numLine++;
    if (checkComment()) { # Skip comment and empty string
	$res = checkSyntax();
	if ($res ne "OK") {
	    $result[$ind++] = $numLine; # Number error line
    	    $result[$ind++] = $res;     # First_Word:Last_Word with error
    	    $result[$ind++] = $_;       # Cheking line
	}
    }
};
close(MC);

if ($#result == -1) {
    okOut $nameMC;
} else {
    errOut;
}

print "---------\nEnd\n";

=head4 (c) VIl

=head4 19.08.2016

=cut

__END__
