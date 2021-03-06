#!./perl -w

use strict;
use Test::More;
use Config;

BEGIN {
    plan(skip_all => "\$^O eq '$^O'") if $^O eq 'VMS';
    plan(skip_all => "POSIX is unavailable")
	unless $Config{extensions} =~ /\bPOSIX\b/;
    unshift @INC, "../../t";
    require 'loc_tools.pl';
}

use POSIX;

# E.g. \t might or might not be isprint() depending on the locale,
# so let's reset to the default.
setlocale(LC_ALL, 'C') if locales_enabled('LC_ALL');

$| = 1;

# List of characters (and strings) to feed to the is<xxx> functions.
#
# The left-hand side (key) is a character or string.
# The right-hand side (value) is a list of character classes to which
# this string belongs.  This is a *complete* list: any classes not
# listed, are expected to return '0' for the given string.
my %classes =
  (
   'a'    => [ qw(print graph alnum alpha lower xdigit) ],
   'A'    => [ qw(print graph alnum alpha upper xdigit) ],
   'z'    => [ qw(print graph alnum alpha lower) ],
   'Z'    => [ qw(print graph alnum alpha upper) ],
   '0'    => [ qw(print graph alnum digit xdigit) ],
   '9'    => [ qw(print graph alnum digit xdigit) ],
   '.'    => [ qw(print graph punct) ],
   '?'    => [ qw(print graph punct) ],
   ' '    => [ qw(print space) ],
   "\t"   => [ qw(cntrl space) ],
   "\001" => [ qw(cntrl) ],

   # Multi-character strings.  These are logically ANDed, so the
   # presence of different types of chars in one string will
   # reduce the list on the right.
   'abc'       => [ qw(print graph alnum alpha lower xdigit) ],
   'az'        => [ qw(print graph alnum alpha lower) ],
   'aZ'        => [ qw(print graph alnum alpha) ],
   'abc '      => [ qw(print) ],

   '012aF'     => [ qw(print graph alnum xdigit) ],

   " \t"       => [ qw(space) ],

   "abcde\001" => [],

   # An empty string. Always true (al least in old days) [bug #24554]
   ''     => [ qw(print graph alnum alpha lower upper digit xdigit
                  punct cntrl space) ],
  );


# Pass 1: convert the above arrays to hashes.  While doing so, obtain
# a complete list of all the 'is<xxx>' functions.  At least, the ones
# listed above.
my %functions;
foreach my $s (keys %classes) {
    $classes{$s} = { map {
	$functions{"is$_"}++;	# Keep track of all the 'is<xxx>' functions
	"is$_" => 1;		# Our return value: is<xxx>($s) should pass.
    } @{$classes{$s}} };
}

# Expected number of tests is one each for every combination of a
# known is<xxx> function and string listed above.
plan(tests => keys(%classes) * keys(%functions) + 2);

# Main test loop: Run all POSIX::is<xxx> tests on each string defined above.
# Only the character classes listed for that string should return 1.  We
# always run all functions on every string, and expect to get 0 for the
# character classes not listed in the given string's hash value.
#
foreach my $s (sort keys %classes) {
    foreach my $f (sort keys %functions) {
	my $expected = exists $classes{$s}->{$f};
	my $actual   = eval "no warnings 'deprecated'; POSIX::$f( \$s )";

	cmp_ok($actual, '==', $expected, "$f('$s')");
    }
}

{
    my @warnings;
    local $SIG {__WARN__} = sub { push @warnings, @_; };

    foreach (0 .. 3) {
        my $a;
        $a =POSIX::isalnum("a");
        $a =POSIX::isalpha("a");
        $a =POSIX::iscntrl("a");
        $a =POSIX::isdigit("a");
        $a =POSIX::isgraph("a");
        $a =POSIX::islower("a");
        $a =POSIX::ispunct("a");
        $a =POSIX::isspace("a");
        $a =POSIX::isupper("a");
        $a =POSIX::isxdigit("a");
        $a =POSIX::isalnum("a");
        $a =POSIX::isalpha("a");
        $a =POSIX::iscntrl("a");
        $a =POSIX::isdigit("a");
        $a =POSIX::isgraph("a");
        $a =POSIX::islower("a");
        $a =POSIX::ispunct("a");
        $a =POSIX::isspace("a");
        $a =POSIX::isupper("a");
        $a =POSIX::isxdigit("a");
    }

    # Each of the 10 classes should warn twice, because each has 2 lexical
    # calls
    is(scalar @warnings, 20);
}

SKIP:
{
    # [perl #122476] - is*() could crash when threads were involved on Win32
    # this only crashed on Win32, only test there
    # When the is*() functions are removed, also remove "iscrash"
    skip("Not Win32", 1) unless $^O eq "MSWin32";
    skip("No threads", 1) unless $Config{useithreads};
    skip("No Win32API::File", 1)
      unless $Config{extensions} =~ m(\bWin32API/File\b);

    local $ENV{PERL5LIB} =
      join($Config{path_sep},
	   map / / ? qq("$_") : $_, @INC);
    my $result = `$^X t/iscrash`;
    like($result, qr/\bok\b/, "is in threads didn't crash");
}
