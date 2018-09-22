use Outthentic::DSL;

my $otx = Outthentic::DSL->new(<<'HERE');
  I am ok
HERE

$otx->validate(from_string => <<'CHECK');
  I am OK
CHECK

print "status\tcheck\n";
print "==========================\n";

for my $r (@{$otx->results}) {
    print $r->{status} ? 'true' : 'false', "\t", $r->{message}, "\n";
}


