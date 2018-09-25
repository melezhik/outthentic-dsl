use Outthentic::DSL;

my $otx = Outthentic::DSL->new('hello');

$otx->validate(from_string => <<'CHECK');
  hello
  code: print "hi there!\n";
CHECK

for my $r (@{$otx->results}) {
    print $r->{status} ? 'true' : 'false', "\t", $r->{message}, "\n";
}

