package Outthentic::DSL::Context::Range;


sub new { 

    my $class   = shift;
    my $expr    = shift;

    my ($a, $b) = split /\s+/, $expr;

    s{\s+}[] for $a, $b;

    $a ||= '.*';
    $b ||= '.*';

    my $self = bless {}, $class;

    $self->{bound_l} = qr/$a/;
    $self->{bound_r} = qr/$b/;

    $self;
}

sub change_context {

    my $self        = shift;
    my $cur_ctx     = shift; # current search context
    my $orig_ctx    = shift; # original search context
    my $succ        = shift; # latest succeeded items

    my $bound_l = $self->{bound_l};
    my $bound_r = $self->{bound_r};

    my @dc = ();
    my @chunk;

    my $inside = 0;

    for my $c (@{$cur_ctx}){

        if ( $inside and $c->[0] !~ $bound_r ){
            push @chunk, $c;
            next;
        }

        if ( $inside and $c->[0] =~ $bound_r  ){

            push @dc, @chunk;

            @chunk = ();
            $inside = 0;
            next;
        }


        if ($c->[0] =~ $bound_l){
            $inside = 1;
            next;
        }

    }


    return [@dc];
}



1;

