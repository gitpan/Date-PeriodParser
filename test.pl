# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 1 };
use Date::PeriodParser;
ok(2); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

$Date::PeriodParser::TestTime = 1018645296;
# (22:01:36 12/4/2002)

my %tests =  (
        "round about now"  => [ 1018644996, 1018645596 ],
                    today  => [ 1018566000, 1018652399 ],
                yesterday  => [ 1018479600, 1018565999 ],
      "yesterday morning"  => [ 1018479600, 1018522800 ], 
"the day before yesterday" => [ 1018393200, 1018479599 ], 
        "tomorrow evening" => [ 1018717200, 1018738799 ],
              "last night" => [ 1018555200, 1018587600 ],
          "this afternoon" => [ 1018614600, 1018630800 ],
          "tonight"        => [ 1018641600, 1018674000 ],
        "4 days ago"       => [ 1018220400, 1018306799 ],
        "roughly yesterday afternoon" => [1018521000, 1018551600],
 "around the morning of the day before yesterday" => [1018386000, 1018443600],
 "roughly eleven days ago" => [ 1017486000, 1017831599 ],
);

for (keys %tests) {
    my ($from, $to) = parse_period($_);
    my ($efrom, $eto) = @{$tests{$_}};
    if ($from == $efrom and $to == $eto) {
        ok(1);
    } else {
        print "($from, $to) != ($efrom, $eto)\n";
        print "Saw from @{[ scalar localtime $from ]}, expected @{[ scalar localtime $efrom ]} for $_\n" if $from != $efrom;
        print "Saw to @{[ scalar localtime $to ]}, expected @{[ scalar localtime $eto ]} for $_\n" if $to != $eto;
        ok(0);
    }
}

#print $_, ", " for keys %tests;
