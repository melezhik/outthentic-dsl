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

       unless ($self->{chains}){
            for my $c ( @{$succ} ){
                $self->{chains}->{$c->[1]} = [$c];
            }
       };

       my %keep_chain = map { $_ => 0 } keys %{$self->{chains}};
         
       for my $c (@{$succ}){
            my $next_i = $c->[1];
            push @$next_chunk, $orig_ctx->[$next_i];
            my $kc;
            for my $cid (keys %{$self->{chains}}){
                #warn "a: ".($self->{chains}->{$cid}->[-1]->[1]);
                #warn "b: ".($next_i-1);
                if ( $self->{chains}->{$cid}->[-1]->[1] == $next_i-1 ){
                    $kc = $cid;
                    $keep_chain{$cid} = 1;
                    #warn "$c->[0]"
                }
            }
            push @{$self->{chains}->{$kc}}, $c if $kc; 
        }
    }else{
        $next_chunk = $cur_ctx; 
    }

    for my $cid ( keys %keep_chain ){
        $self->{chains}->{$cid} = undef unless $keep_chain{$cid};
    }        
    $next_chunk;

}


1;

