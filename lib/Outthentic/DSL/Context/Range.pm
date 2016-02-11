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


    $self->{ranges} ||= []; # this is initial ranges object

    my $a_indx;
    my $b_index;


    for my $c (@{$cur_ctx}){


        if ( $inside and $c->[0] !~ $bound_r ){
            push @chunk, $c;
            next;
        }

        if ( $inside and $c->[0] =~ $bound_r  ){


            push @dc, @chunk;

            push @dc, ["#dsl_note: end range"];

            @chunk = ();

            $inside = 0;

            $b_index = $c->[1]-1;
            push @{$self->{ranges}}, [$a_index, $b_index];
            $self->{chains}->{$a_index} ||= [];
            next;
        }


        if ($c->[0] =~ $bound_l){
            $inside = 1;
            $a_index = $c->[1]-1;
            push @chunk, ["#dsl_note: start range"];
            next;
        }

    }

    return [@dc];
}



sub update_stream {

    my $self        = shift;
    my $cur_ctx     = shift; # current search context
    my $orig_ctx    = shift; # original search context
    my $succ        = shift; # latest succeeded items
    my $stream_ref  = shift; # reference to stream object to update

    my $inside = 0;

    $self->{chains} ||= {}; # this is initial chain object
    $i = 0;

    for my $c (@{$succ}){

        for my $r (@{$self->{ranges}}){
            my $a_index = $r->[0];
            my $b_index = $r->[1];
            #warn "kkk $a_index ... $b_index";
            #warn ($c->[0]);
            #warn ($c->[1]-1);
            #warn "----";
            if ($c->[1]-1 >= $a_index and $c->[1]-1 <= $b_index  ){
                push @{$self->{chains}->{$a_index}}, $c;
                #warn "OK!";
            }

        }

    }

    ${$stream_ref} = $self->{chains};

}

1;

