use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Test::More;

require "$FindBin::Bin/hitl.pl";

my $output = '';
open my $fh, '>', \$output or die "open scalar: $!\n";
run($fh);
close $fh;

is(
    $output,
    "approve: written; effects=1\nedit: policy rejected; effects=0\n",
    'hitl approve and edit scenarios',
);

done_testing();
