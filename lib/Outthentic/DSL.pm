package Outthentic::DSL;

use strict;
require Test::More;

our $VERSION = '0.0.2';

sub new {

    my $class = shift;
    my $opts = shift;

    bless {
        context => [],
        context_local => [],
        context_populated => 0,
        captures => [],
        within_mode => 0,
        block_mode => 0,
        last_match_line => undef,
        last_check_status => undef,
        debug_mod => 0,
        output => undef,
        match_l => 40,
        $opts,
    }, __PACKAGE__;

}

sub populate_context {

    my $self = shift;

    return if $self->{context_populated};

    my $i = 0;

    my @context = ();

    for my $l ( split /\n/, $self->{output} ){
        chomp $l;
        $i++;
        $l=":blank_line" unless $l=~/\S/;
        push @context, [$l, $i];
    }

    $self->{context} = [@context];
    $self->{context_local} = [@context];

    Test::More::diag("context populated") if $self->{debug_mod} >= 2;

    $self->{context_populated} = 1;


}

sub reset_captures {

    my $self = shift;
    $self->{captures} = [];

}

sub check_line {

    my $self = shift;
    my $pattern = shift;
    my $check_type = shift;
    my $message = shift;

    my $status = 0;


    $self->reset_captures;

    my @captures;

    $self->populate_context;

    Test::More::diag("lookup $pattern ...") if $self->{debug_mod} >= 2;

    my @context         = @{$self->{context}};
    my @context_local   = @{$self->{context_local}};
    my @context_new     = ();

    if ($check_type eq 'default'){
        for my $c (@context_local){
            my $ln = $c->[0]; my $next_i = $c->[1];
            if ( index($ln,$pattern) != -1){
                $status = 1;
                $self->{last_match_line} = $ln;
            }
            push @context_new, $context[$next_i] if $self->{block_mode};
        }
    }elsif($check_type eq 'regexp'){
        for my $c (@context_local){
            my $re = qr/$pattern/;
            my $ln = $c->[0]; my $next_i = $c->[1];

            my @foo = ($ln =~ /$re/g);

            if (scalar @foo){
                push @captures, [@foo];
                $status = 1;
                push @context_new, $c if $self->{within_mode};
                $self->{last_match_line} = $ln;
            }
            push @context_new, $context[$next_i] if $self->{block_mode};

        }
    }else {
        die "unknown check_type: $check_type";
    }

    Test::More::ok($status,$message);
    $self->{last_check_status} = $status;

    if ( $self->{debug_mod} >= 2 ){
        my $k=0;
        for my $ce (@captures) {
            $k++;
            Test::More::diag("captured item N $k");
            for  my $c (@{$ce}){
                Test::More::diag("\tcaptures: $c");
            }
        }
    }

    $self->{captures} = [ @captures ];

    # update context
    if ( $self->{block_mode} ){
        $self->{context_local} = [@context_new];
    } elsif ( $self->{within_mode} and $status ){
        $self->{context_local} = [@context_new];
    }

    return $status;

}

sub generate_asserts {

    my $self = shift;

    my $filepath_or_array_ref = shift;

    my @lines;
    my @multiline_chunk;
    my $chunk_type;

    if ( ref($filepath_or_array_ref) eq 'ARRAY') {
        @lines = @$filepath_or_array_ref
    }else{
        return unless $filepath_or_array_ref;
        open my $fh, $filepath_or_array_ref or die $!;
        while (my $l = <$fh>){
            push @lines, $l
        }
        close $fh;
    }


    LINE: for my $l (@lines){

        chomp $l;

        Test::More::diag $l if $self->{debug_mod} >= 3;

        next LINE unless $l =~ /\S/; # skip blank lines

        next LINE if $l=~ /^\s*#(.*)/; # skip comments

        if ($l=~ /^\s*begin:\s*$/) { # begin of text block
            Test::More::diag("begin text block") if $self->{debug_mod} >= 2;
            $self->{block_mode} = 1;
            next LINE;
        }
        if ($l=~ /^\s*end:\s*$/) { # end of text block

            $self->{block_mode} = 0;

            # restore local context
            $self->{context_local} = $self->{context};

            Test::More::diag("end text block") if $self->{debug_mod} >= 2;

            next LINE;
        }

        # validate unterminated multiline chunks
        if ($l=~/^\s*(regexp|code|generator|within):\s*.*/){
            die "unterminated multiline $chunk_type found, last line: $multiline_chunk[-1]" if defined($chunk_type);
        }

        if ($l=~/^\s*code:\s*(.*)/){ # `code' line

            my $code = $1;
            if ($code=~s/\\\s*$//){
                 push @multiline_chunk, $code;
                 $chunk_type = 'code';
                 next LINE; # this is multiline chunk, accumulate lines until meet '\' line
            }else{
                undef $chunk_type;
                $self->handle_code($code);
            }

        }elsif($l=~/^\s*generator:\s*(.*)/){ # `generator' line

            my $code = $1;

            if ($code=~s/\\\s*$//){
                 push @multiline_chunk, $code;
                 $chunk_type = 'generator';
                 next LINE; # this is multiline chunk, accumulate lines until meet '\' line

            }else{
                $self->handle_generator($code);
            }

        }elsif($l=~/^\s*regexp:\s*(.*)/){ # `regexp' line

            my $re=$1;
            $self->handle_regexp($re);

        }elsif($l=~/^\s*within:\s*(.*)/){

            my $re=$1;
            $self->handle_within($re);

        }elsif(defined($chunk_type)){ # multiline 

            if ($l=~s/\\\s*$//) {

                push @multiline_chunk, $l;
                next LINE; # this is multiline chunk, accumulate lines until meet '\' line

             }else {

                # the end of multiline chunk
                no strict 'refs';
                my $name = "handle_"; 
                $name.=$chunk_type;
                push @multiline_chunk, $l;
                &$name($self,\@multiline_chunk);

                # flush mulitline chunk data:
                undef $chunk_type;
                @multiline_chunk = ();

            }
       }else{ # `plain string' line

            s{\s+#.*}[], s{\s+$}[], s{^\s+}[] for $l;
            $self->handle_plain($l);

        }
    }

    die "unterminated multiline $chunk_type found, last line: $multiline_chunk[-1]" if defined($chunk_type);

}

sub handle_code {

    my $self = shift;
    my $code = shift;

    unless (ref $code){
        eval "package main; $code;";
        die "code LINE eval perl error, code:$code , error: $@" if $@;
        Test::More::diag("handle_code OK. $code") if $self->{debug_mod} >= 3;
    } else {
        my $code_to_eval = join "\n", @$code;
        eval "package main; $code_to_eval";
        die "code LINE eval error, code:$code_to_eval , error: $@" if $@;
        Test::More::diag("handle_code OK. multiline. $code_to_eval") if $self->{debug_mod} >= 3;
    }

}

sub handle_generator {

    my $self = shift;
    my $code = shift;

    unless (ref $code){
        my $arr_ref = eval "package main; $code";
        die "generator LINE eval error, code:$code , error: $@" if $@;
        Test::More::diag("handle_generator OK. $code") if $self->{debug_mod} >= 3;
        $self->generate_asserts($arr_ref);
    } else {
        my $code_to_eval = join "\n", @$code;
        my $arr_ref = eval " package main; $code_to_eval";
        die "generator LINE eval error, code:$code_to_eval , error: $@" if $@;
        Test::More::diag("handle_generator OK. multiline. $code_to_eval") if $self->{debug_mod} >= 3;
        $self->generate_asserts($arr_ref);
    }

}

sub handle_regexp {

    my $self = shift;
    my $re = shift;
    
    my $m;

    if ($self->{within_mode}){
        $self->{within_mode} = 0; 
        $self->{context_local} = $self->{context};
        if ($self->{last_check_status}){
            my $lml =  $self->_short_string($self->{last_match_line});
            $m = "'$lml' match /$re/";
        } else {
            $m = "output match /$re/";
        }
    } else {
        $m = "output @{[$self->{block_mode} ? 'block' : '' ]} match /$re/";
    }


    $self->check_line($re, 'regexp', $m);

    Test::More::diag("handle_regexp OK. $re") if $self->{debug_mod} >= 3;

}

sub handle_within {

    my $self = shift;
    my $re = shift;

    my $m;

    if ($self->{within_mode}){
        if ($self->{last_check_status}){
            my $lml =  $self->_short_string($self->{last_match_line});
            $m = "'$lml' match /$re/";
        } else {
            $m = "output match /$re/";
        }
    }else{
        $m = "output match /$re/";
    }

    $self->{within_mode} = 1;

    $self->check_line($re, 'regexp', $m);

    Test::More::diag "handle_within OK. $re" if $self->{debug_mod} >= 3;
    
}

sub handle_plain {

    my $self = shift;
    my $l = shift;

    my $m;
    my $lshort =  $self->_short_string($l);

    if ($self->{within_mode}){
        $self->{within_mode} = 0;
        $self->{context_local} = $self->{context}; 
        if ($self->{last_check_status}){
            my $lml =  $self->_short_string($self->{last_match_line});
            $m = "'$lml' match '$lshort'";
        } else{
            $m = "output match '$lshort'";
        }
    }else{
        $m = "output @{[$self->{block_mode} ? 'block' : '' ]} match '$lshort'";
    }


    $self->check_line($l, 'default', $m);

    Test::More::diag("handle_plain OK. $l") if $self->{debug_mod} >= 3;
}


sub _short_string {

    my $self = shift;
    my $str = shift;
    my $sstr = substr( $str, 0, $self->{match_l} );

    
    return $sstr < $str ? "$str ..." : $str; 

}

1;


__END__

=head1 SYNOPSIS

Outthentic DSL

=head1 Documentation

Please follow github pages  - https://github.com/melezhik/outthentic-dsl

=head1 AUTHOR

Aleksei Melezhik

=head1 COPYRIGHT

Copyright 2015 Alexey Melezhik.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

