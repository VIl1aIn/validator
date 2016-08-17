#!/usr/bin/perl -w

use strict;

# Init section

my $nameMC = defined $ARGV[0]?$ARGV[0]:"service.mc";
my $nameDict = defined $ARGV[1]?$ARGV[1]:"dictionary.txt";


if ("$nameMC" eq "--help"|
	"$nameMC" eq "-h"|
	"$nameMC" eq "-?") {
		print <<EOF;
Usage: $0 <dictionary> name-file.mc>
EOF
	exit 0;
}

print "$nameDict\n";
print "$nameMC\n";


__END__