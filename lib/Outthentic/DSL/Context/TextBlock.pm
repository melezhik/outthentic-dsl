package Outthentic::DSL::Context::TextBlock;
use Data::Dumper;


sub new { 

    bless { succeeded => [] }, __PACKAGE__
}

sub change_context {

    my $self        = shift;
    my $cur_ctx     = shift; # current search context
    my $orig_ctx    = shift; # original search context
    my $succ        = shift; # latest succeeded items

    #warn Dumper($cur_ctx);
    #warn Dumper($succ);

    my $next_chunk  = [];
    if (scalar @{$succ}){

       for my $c (@{$succ}){
            my $next_i = $c->[1];
            push @$next_chunk, $orig_ctx->[$next_i];
        }
    }else{
        $next_chunk = $cur_ctx; 
    }

    $next_chunk;

}


sub update_stream {

    my $self        = shift;
    my $succ        = shift; # latest succeeded items
    my $stream_ref  = shift;

    use Data::Dumper;

    my @keep_chains;


    if (scalar @{$succ}){

       unless ($self->{chains}){
            for my $c ( @{$succ} ){
                $self->{chains}->{$c->[1]} = [$c];
                ${$stream_ref}->{$c->[1]} =  [$c];
            }
       };


       for my $c (@{$succ}){
            my $kc;
            my $next_i = $c->[1];
            for my $cid (keys %{$self->{chains}}){
                if ( $self->{chains}->{$cid}->[-1]->[1] == $next_i-1 ){
                    $kc = $cid;
                    push @keep_chains, $cid;
                }
            }
            push @{$self->{chains}->{$kc}}, $c if $kc; 
        }
    }

    #warn 100;
    #warn Dumper($succ);
    #warn Dumper($self->{chains});
    #warn Dumper(\@keep_chains);

    for my $cid ( @keep_chains ){
        ${$stream_ref}->{$cid} = $self->{chains}->{$cid};
    }        

    
}


1;

