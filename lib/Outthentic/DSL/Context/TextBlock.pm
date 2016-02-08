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


1;

