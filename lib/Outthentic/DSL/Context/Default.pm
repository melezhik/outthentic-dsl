package Outthentic::DSL::Context::Default;


sub new { bless {}, __PACKAGE__ }

sub change_context { 

    my $self = shift;
    my $ctx  = shift;

    return $ctx;
}



1;

