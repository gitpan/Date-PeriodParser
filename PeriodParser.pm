package Date::PeriodParser;
use Lingua::EN::Words2Nums;
use 5.006;
use strict;
use warnings;
use Time::Local;

sub debug {
    #print @_, "\n";
}

use constant GIBBERISH => -1;
use constant AMBIGUOUS => -2;

# Boring administrative details
require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw( parse_period	) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw( parse_period);
our $VERSION = '0.01';

our $TestTime; # This is set by test.pl so we don't have to be dynamic

my $roughly = qr/((?:a?round(?: about)?|about|roughly|circa|sometime)\s*)+/;

sub parse_period {
    local $_ = lc shift; # Since we're doing lots of regexps on it.
    my $when = $TestTime || time;
    my ($s, $m, $h, $day, $mon, $year) = (localtime $when)[0..5];

    # Tidy slightly.
    s/^\s+//;s/\s+$//;
    return GIBBERISH unless $_;

    # We're trying to find two things: from and to.
    # We also want to keep track of how vague the user's being, so we
    # provide a flexibility score - for instance "about two weeks ago"
    # means maybe three days either side, but "around last September"
    # means perhaps twelve days either side. 
    my ($from, $to, $leeway);
    my $vague = s/^$roughly\s*//;
    
    # Stupid cases first.
    return apply_leeway($when, $when, 300 * $vague) # 5 minutes either side
        if /^now$/;

    if ($_ eq "sometime") { # Smart bastard
        $from = 0; $to = 2**32-1;
        return ($from, $to);
    }

    # Recent times
    if (/(the day (before|after) )?(yesterday|today|tomorrow)/ || 
        /^this (morning|afternoon|evening|lunchtime)$/ || 
        /^(last |to)night/) {

        if (s/the day (before|after)//) {
            my $wind = $1 eq "before" ? -1 : 1;
            debug("Modifying day by $wind");
            $day += $wind;
        }
        if (/yesterday/)   { $day--; debug("Back 1 day") }
        elsif (/tomorrow/) { $day++; debug("Forward 1 day") }
        $day-- if /last/;
        ($from, $to, $leeway) = period_or_all_day($day, $mon, $year);
        return apply_leeway($from, $to, $leeway * $vague);
    }

    s/a week/seven days/g;
    if (/^(.*) days ago$/ || /^in (.*) days(?: time)$/ || 
        /^(.*) days (?:away)?\s*(?:from now)?$/) {
        my $days = $1;
        my $save_val = $_;
        if (defined ($days=words2nums($days))) { # This trashes $_
            $_ = $save_val;
            $days *= -1 if /ago/;
            debug("Modifying day by $days");
            $day += $days;
            ($from, $to, $leeway) = period_or_all_day($day, $mon, $year);
            return apply_leeway($from, $to, $leeway * $vague);
        }
     }

    DONE:
    # Apply leeway
    if (/about|around|roughly|circa/) {
        $from -= $leeway; $to += $leeway;
    }
    if (!$from and !$to) {
        return (GIBBERISH, "I couldn't parse that at all.");
    }
}

my %points_of_day = (
    morning   => [
                    [0, 0, 0],
                    [12, 0, 0]
                 ],
    lunchtime => [
                    [12, 0, 0],
                    [13,30, 0]
                 ],
    afternoon => [
                    [13,30, 0], # "It is not afternoon until a gentleman
                    [18, 0, 0]  # has had his luncheon."
                 ],
    evening   => [
                    [18, 0, 0], # Regardless of what Mediterraneans think
                    [23,59,59]
                 ],
    day       => [
                    [0, 0, 0],
                    [23,59,59],
                 ]
);

sub apply_point_of_day {
    my ($d, $m, $y, $point) = @_;
    my ($from, $to); 
    debug("Applying $d/$m/$y -> $point");
    if ($point eq "night") { # Special case
        $from = timelocal(0,0,21,$d,$m,$y);
        $to   = timelocal(0,0, 6,$d+1,$m,$y);
    } else {
        my $spec = $points_of_day{$point};
        debug("Spec is $point\n");
        my @from = (reverse(@{$spec->[0]}),$d,$m,$y);
        my @to   = (reverse(@{$spec->[1]}),$d,$m,$y);
        debug("From is timelocal(@from)");
        debug("To is timelocal(@to)");
        $from = timelocal(@from);
        $to   = timelocal(@to);
    }
    return ($from, $to);
}

sub period_or_all_day {
    my $point;
    my ($day, $mon, $year) = @_;
    my $leeway;

    /(morning|afternoon|evening|lunchtime|night)/;
    if ($1) {
        $leeway = 60*60*2;
        $point = $1;
    } else {
        # To determine the leeway, consider how many days ago this was;
        # we want to be more specific about recent events than ancient
        # ones.
        my $was = timelocal(0,0,0, $day, $mon, $year);
        my $now = $TestTime || time;
        my $days_ago = int(($now-$was)/(60*60*24))+1;
        $leeway = 60*60*3*$days_ago;
        # Up to a maximum of five days
        $leeway > 24*60*60*5 and $leeway = 24*60*60*5;
        debug("Wanted around $days_ago, allowing $leeway either side");
        $point = "day";
    }
    return (apply_point_of_day($day, $mon, $year, $point), $leeway);
}

sub apply_leeway {
    my ($from, $to, $leeway) = @_;
    $from -= $leeway; $to += $leeway;
    return ($from, $to);
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Date::PeriodParser - Turns English descriptions into time periods

=head1 SYNOPSIS

  use Date::PeriodParser;
  my ($midnight, $midday) = parse_period("this morning");
  my ($monday_am, $sunday_pm) = parse_period("this week");
  ... parse_period("sometime last September");
  ... parse_period("around two weeks ago");


=head1 DESCRIPTION

The subroutine C<parse_period> attempts to turn the English description
of a time period into a pair of Unix epoch times. As a famous man once
said, "Of course, this is a heuristic, which is a fancy way of saying
that it doesn't work". I'm happy with it, though. (or at least, I will
be; this is currently very much a work in progress, and only knows about
recent dates.)

If you enter something it can't parse, it'll return an error code and an
explanation instead of two epoch time values. Error code -1 means "You
entered gibberish", error code -2 means "you entered something
ambiguous", and the explanation will tell you how to disambiguate it.

=head1 AUTHOR

Simon Cozens, C<simon@cpan.org>

=cut
