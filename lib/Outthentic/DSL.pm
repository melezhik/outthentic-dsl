package Outthentic::DSL;

use strict;

our $VERSION = '0.1.1';

use Carp;
use Data::Dumper;
use Outthentic::DSL::Context::Range;
use Outthentic::DSL::Context::Default;
use Outthentic::DSL::Context::TextBlock;
use File::Temp qw/ tempfile /;
use JSON;

$Data::Dumper::Terse=1;

sub results {

    my $self = shift;

    $self->{results};
}

sub add_result {

    my $self = shift;
    my $item = shift;

    push @{$self->results}, { %{$item}, type => 'check_expression' };
        
}

sub add_debug_result {

    my $self = shift;
    my $item = shift;

    push @{$self->results}, { message => $item , type => 'debug' };
        
}


sub new {

    my $class = shift;
    my $output = shift;
    my $opts = shift || {};

    bless {
        results => [],
        original_context => [],
        current_context => [],
        context_modificator => Outthentic::DSL::Context::Default->new(),
        has_context => 0,
        succeeded => [],
        captures => [],
        within_mode => 0,
        block_mode => 0,
        last_match_line => undef,
        last_check_status => undef,
        debug_mod => 0,
        output => $output||'',
        match_l => 40,
        stream => {},
        languages => {},
        %{$opts},
    }, __PACKAGE__;

}

sub create_context {

    my $self = shift;

    return if $self->{has_context};

    my $i = 0;

    my @original_context = ();

    for my $l ( split /\n/, $self->{output} ){
        chomp $l;
        $i++;
        $l=":blank_line" unless $l=~/\S/;
        push @original_context, [$l, $i];

        $self->add_debug_result("[oc] [$l, $i]") if $self->{debug_mod} >= 2;

    }

    $self->{original_context} = [@original_context];

    $self->{current_context} = [@original_context];

    $self->add_debug_result('context populated') if $self->{debug_mod} >= 2;


    $self->{has_context} = 1;


}


sub reset_captures {

    my $self = shift;
    $self->{captures} = [];
    unlink $self->{cache_dir}."/captures.json" if -f $self->{cache_dir}."/captures.json";
}

sub reset_succeeded {

    my $self = shift;
    $self->{succeeded} = [];

}

sub reset_context {

    my $self = shift;

    $self->{current_context} = $self->{original_context};

    $self->add_debug_result('reset search context') if $self->{debug_mod} >= 2;

    $self->{context_modificator} = Outthentic::DSL::Context::Default->new();

}

sub stream {

    my $self = shift;
    my @stream;
    my $i=0;

    for my $cid ( sort { $a <=> $b } keys  %{$self->{stream}} ){
        $stream[$i]=[];
        for my $c (@{$self->{stream}->{$cid}}){
            push @{$stream[$i]}, $c->[0];
            $self->add_debug_result("[stream {$cid} [$i]] $c->[0]") if $self->{debug_mod} >= 2;
        }
        $i++;
    }
    [@stream]
}

sub match_lines {

    my $self = shift;
    return $self->{succeeded};
}


sub check_line {

    my $self = shift;
    my $pattern = shift;
    my $check_type = shift;
    my $message = shift;

    my $status = 0;


    $self->reset_captures;

    my @captures = ();

    $self->create_context;

    $self->add_debug_result("[lookup] $pattern ...") if $self->{debug_mod} >= 2;

    my @original_context   = @{$self->{original_context}};
    my @context_new        = ();

    # dynamic context 
    my $dc = $self->{context_modificator}->change_context(
        $self->{current_context},
        $self->{original_context},
        $self->{succeeded}
    );

    $self->add_debug_result("context modificator applied: ".(ref $self->{context_modificator})) 
        if $self->{debug_mod} >=2;
        
    if ( $self->{debug_mod} >= 2 ) {
        for my $dcl (@$dc){ 
            $self->add_debug_result("[dc] $dcl->[0]");
        } 

    };
    

    $self->reset_succeeded;

    if ($check_type eq 'default'){
        for my $c (@{$dc}){

            my $ln = $c->[0];
            next if $ln =~/#dsl_note:/;

            if ( index($ln,$pattern) != -1){
                $status = 1;
                $self->{last_match_line} = $ln;
                push @{$self->{succeeded}}, $c;
            }
        }

    }elsif($check_type eq 'regexp'){


        for my $c (@{$dc}) {

            my $re = qr/$pattern/;

            my $ln = $c->[0];

            next if $ln eq ":blank_line";
            next if $ln =~/#dsl_note:/;

            my @foo = ($ln =~ /$re/g);

            if (scalar @foo){
                push @captures, [@foo];
                $status = 1;
                push @{$self->{succeeded}}, $c;
                push @context_new, $c if $self->{within_mode};
                $self->{last_match_line} = $ln;
            }

        }
    }else {
        confess "unknown check_type: $check_type";
    }



    $self->{last_check_status} = $status;

    if ( $self->{debug_mod} >= 2 ){

        my $i = -1;
        my $j = -1;
        for my $cpp (@captures){
            $i++;
            for my $cp (@{$cpp}){
                $j++;
                $self->add_debug_result("CAP[$i,$j]: $cp");
            }
            $j=0;
        }

        for my $s (@{$self->{succeeded}}){
            $self->add_debug_result("SUCC: $s->[0]");
        }
    }

    $self->{captures} = [ @captures ];

    if ($self->{cache_dir}){
      open CAPTURES, '>', $self->{cache_dir}.'/captures.json' 
        or confess "can't open ".($self->{cache_dir})."captures.json to write $!";
      print CAPTURES encode_json($self->{captures});
      $self->add_debug_result("CAPTURES saved at ".$self->{cache_dir}.'/captures.json')
        if $self->{debug_mod} >= 1;
      close CAPTURES;
    }

    # update context
    if ( $self->{within_mode} and $status ){
        $self->{current_context} = [@context_new];
        $self->add_debug_result('within mode: modify search context to: '.(Dumper([@context_new]))) if $self->{debug_mod} >= 2 
    }elsif ( $self->{within_mode} and ! $status ){
        $self->{current_context} = []; # empty context if within expression has not passed 
        $self->add_debug_result('within mode: modify search context to: '.(Dumper([@context_new]))) if $self->{debug_mod} >= 2 
    }

    $self->add_result({ status => $status , message => $message });


    $self->{context_modificator}->update_stream(
        $self->{current_context},
        $self->{original_context},
        $self->{succeeded}, 
        \($self->{stream}),
    );

    return $status;

}

sub validate {

    my $self = shift;

    my $filepath_or_array_ref = shift;

    my @lines;
    my @multiline_chunk;
    my $chunk_type;

    if ( ref($filepath_or_array_ref) eq 'ARRAY') {
        @lines = @$filepath_or_array_ref
    }else{
        return unless $filepath_or_array_ref;
        open my $fh, $filepath_or_array_ref or confess $!;
        while (my $l = <$fh>){
            push @lines, $l
        }
        close $fh;
    }

    my $multiline_mode;

    LINE: for my $l (@lines){

        chomp $l;

        $self->add_debug_result("[dsl] $l") if $self->{debug_mod} >= 2;

        next LINE unless $l =~ /\S/; # skip blank lines

        next LINE if $l=~ /^\s*#(.*)/; # skip comments
        
        if ($multiline_mode){
            if ($l=~s/^$multiline_mode$//){
              $multiline_mode = undef; 
              $self->add_debug_result("multiline_mode off") if $self->{debug_mod} >= 2;
            }
        }

        if ($l=~ /^\s*begin:\s*$/) { # begin of text block
            confess "you can't switch to text block mode when within mode is enabled" 
                if $self->{within_mode};

            $self->{context_modificator} = Outthentic::DSL::Context::TextBlock->new();

            $self->add_debug_result('begin text block') if $self->{debug_mod} >= 2;
            $self->{block_mode} = 1;

            $self->reset_succeeded;

            next LINE;
        }

        if ($l=~ /^\s*end:\s*$/) { # end of text block

            $self->{block_mode} = 0;

            $self->reset_context;

            $self->add_debug_result('end text block') if $self->{debug_mod} >= 2;

            next LINE;
        }

        if ($l=~ /^\s*reset_context:\s*$/) {

            $self->reset_context;

            next LINE;
        }

        if ($l=~ /^\s*assert:\s(\S+)\s+(.*)$/) {
            $self->add_debug_result("assert found: $1,$2") if $self->{debug_mod} >= 2;
            $self->add_result({ status => $1 , message => $2 });
            next LINE;
        }

        if ($l=~ /^\s*between:\s+(.*)/) { # set new context
            
            $self->{context_modificator} = Outthentic::DSL::Context::Range->new($1);

            confess "you can't set context modificator when within mode is enabled" 
                if $self->{within_mode};

            confess "you can't set context modificator when text block mode is enabled" 
                if $self->{block_mode};

            next LINE;
        }

        # validate unterminated multiline chunks
        if ($l=~/^\s*(regexp|code|generator|within|validator):\s*.*/){
            confess "unterminated multiline $chunk_type found, last line: $multiline_chunk[-1]" 
              if defined($chunk_type);
        }

        if ($l=~/^\s*code:\s*(.*)/){ # `code' line

            my $code = $1;

            if ($code=~s/\\\s*$//){
                 push @multiline_chunk, $code;
                 $chunk_type = 'code';
                 next LINE; # this is multiline chunk, accumulate lines until meet '\' line
            }elsif($code=~s/<<(\S+)//){
                $multiline_mode = $1;
                $chunk_type = 'code';
                $self->add_debug_result("code: multiline_mode on. marker: $multiline_mode") if $self->{debug_mod} >= 2;
                next LINE;
            }else{
                undef $chunk_type;
                $self->handle_code($code);
            }

        }elsif($l=~/^\s*validator:\s*(.*)/){ # `validator' line

            my $code = $1;

            if ($code=~s/\\\s*$//){
                 push @multiline_chunk, $code;
                 $chunk_type = 'validator';
                 next LINE; # this is multiline chunk, accumulate lines until meet '\' line

            }elsif($code=~s/<<(\S+)//){
                $multiline_mode = $1;
                $chunk_type = 'validator';
                $self->add_debug_result("validator: multiline_mode on. marker: $multiline_mode") if $self->{debug_mod} >= 2;
                next LINE;
            }else{
                $self->handle_validator($code);
            }

        }elsif($l=~/^\s*generator:\s*(.*)/){ # `generator' line

            my $code = $1;

            if ($code=~s/\\\s*$//){
                 push @multiline_chunk, $code;
                 $chunk_type = 'generator';
                 next LINE; # this is multiline chunk, accumulate lines until meet '\' line

            }elsif($code=~s/<<(\S+)//){
                $multiline_mode = $1;
                $chunk_type = 'generator';
                $self->add_debug_result("generator: multiline_mode on. marker: $multiline_mode") if $self->{debug_mod} >= 2;
                next LINE;
            }else{
                $self->handle_generator($code);
            }

        }elsif($l=~/^\s*regexp:\s*(.*)/){ # `regexp' line

            my $re=$1;
            $self->handle_regexp($re);

        }elsif($l=~/^\s*within:\s*(.*)/){

            confess "you can't switch to within mode when text block mode is enabled" 
                if $self->{block_mode};

            my $re=$1;
            $self->handle_within($re);

        }elsif(defined($chunk_type)){ # multiline 

             if ($l=~s/\\\s*$// or $multiline_mode ) {

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

    confess "unterminated multiline $chunk_type found, last line: $multiline_chunk[-1]" if defined($chunk_type);

}

sub handle_code {

    my $self = shift;
    my $code = shift;

    unless (ref $code){

        eval "package main; $code;";
        confess "eval error; sub:handle_code; code:$code\nerror: $@" if $@;
        $self->add_debug_result("code OK. single line. code: $code") if $self->{debug_mod} >= 3;

    } else {

        my $i = 0;

        my $code_to_print = join "\n", map { my $v=$_; $i++; "[$i] $v" }  @$code;

        if ($code->[0]=~s/^\!(.*)//){

          my $ext_runner = $1;

          my $language = (split /\\/, $ext_runner)[-1];

          if ($language eq 'perl'){

              shift @$code;
              my $code_to_eval = join "\n", @$code;
              eval "package main; $code_to_eval";
              confess "eval error; sub:handle_code; code:\n$code_to_print\nerror: $@" if $@;
              $self->add_debug_result("code OK. inline(perl). $code_to_eval") if $self->{debug_mod} >= 3;

          }else{

            my $source_file = File::Temp->new( DIR => $self->{cache_dir} , UNLINK => 0 );

            shift @$code;

            my $code_to_eval = join "\n", @$code;

            open SOURCE_CODE, '>', $source_file or die "can't open source code file $source_file to write: $!";

            print SOURCE_CODE $code_to_eval;

            close SOURCE_CODE;

            if ($language eq 'bash'){

              if ($self->{languages}->{$language}){
                $ext_runner = "bash -c '".($self->{languages}->{$language})." && source $source_file'";
              }else{
                $ext_runner = "bash -c 'source $source_file'";
              }

            }else{
              $ext_runner.= ' '.$self->{languages}->{$language} if $self->{languages}->{$language};
              $ext_runner.=' '.$source_file;
            }

            my $st = system("$ext_runner 2>$source_file.err 1>$source_file.out");  

            if ($st != 0){
              confess "$ext_runner failed, see $source_file.err for detailes";
            }

            $self->add_debug_result("code OK. inline. $ext_runner") if $self->{debug_mod} >= 2;

            open EXT_OUT, "$source_file.out" or die "can't open file $source_file.out to read: $!";

            while (my $s = <EXT_OUT>){
              print $s;
            }

            close EXT_OUT;

              unless ($ENV{outth_dls_keep_ext_source_code}){
                unlink("$source_file.out");
                unlink("$source_file.err");
                unlink("$source_file");
              }
          }

        }else{

          my $code_to_eval = join "\n", @$code;
          eval "package main; $code_to_eval";
          confess "eval error; sub:handle_code; code:\n$code_to_print\nerror: $@" if $@;
          $self->add_debug_result("code OK. multiline. $code_to_eval") if $self->{debug_mod} >= 3;

        }

    }

}

sub handle_validator {

    my $self = shift;
    my $code = shift;

    unless (ref $code){

        my $r = eval "package main; $code;";
        confess "eval error; sub:handle_validator; code:$code\nerror: $@" if $@;
        confess "not valid return from validator, should be ARRAYREF. got: @{[ref $r]}" unless ref($r) eq 'ARRAY' ;
        $self->add_result({ status => $r->[0] , message => $r->[1] });
        $self->add_debug_result("validator OK. single line. code: $code") if $self->{debug_mod} >= 2;

    } else {
        my $i = 0;
        my $code_to_print = join "\n", map { my $v=$_; $i++; "[$i] $v" }  @$code;
        my $code_to_eval = join "\n", @$code;
        my $r = eval "package main; $code_to_eval";
        confess "eval error; sub:handle_validator; code:\n$code_to_print\nerror: $@" if $@;
        confess "not valid return from validator, should be ARRAYREF. got: @{[ref $r]}" unless ref($r) eq 'ARRAY' ;
        $self->add_result({ status => $r->[0] , message => $r->[1] });
        $self->add_debug_result("validator OK. multiline. code: $code_to_eval") if $self->{debug_mod} >= 2;
    }

}

sub handle_generator {

    my $self = shift;
    my $code = shift;

    unless (ref $code){

        my $arr_ref = eval "package main; $code";
        confess "eval error; sub:handle_generator; code:$code\nerror: $@" if $@;
        confess "not valid return from generator, should be ARRAYREF. got: @{[ref $arr_ref]}" unless ref($arr_ref) eq 'ARRAY' ;
        $self->add_debug_result("generator OK. single line. code: $code") if $self->{debug_mod} >= 3;
        $self->validate($arr_ref);


    } else {

      my $i = 0;

      my $code_to_print = join "\n", map { my $v=$_; $i++; "[$i] $v" }  @$code;

        if ($code->[0]=~s/^\!(.*)//){
  
          my $ext_runner = $1;

          my $language = (split /\\/, $ext_runner)[-1];

          if ($language eq 'perl'){

              shift @$code;

              my $code_to_eval = join "\n", @$code;
              my $code_to_print = join "\n", map { my $v=$_; $i++; "[$i] $v" }  @$code;

              my $arr_ref = eval "package main; $code_to_eval";

              confess "eval error; sub:handle_code; code:\n$code_to_print\nerror: $@" if $@;
              confess "not valid return from generator, should be ARRAYREF. got: @{[ref $arr_ref]}" unless ref($arr_ref) eq 'ARRAY' ;

              $self->add_debug_result("generator OK. inline(perl). $code_to_eval") if $self->{debug_mod} >= 3;

              $self->validate($arr_ref);
          
          } else {

              my $source_file = File::Temp->new( DIR => $self->{cache_dir} , UNLINK => 0 );
    
              shift @$code;
    
              my $code_to_eval = join "\n", @$code;
    
              open SOURCE_CODE, '>', $source_file or die "can't open source code file $source_file to write: $!";
    
              print SOURCE_CODE $code_to_eval;
    
              close SOURCE_CODE;
    
              if ($language eq 'bash'){
  
                if ($self->{languages}->{$language}){
                  $ext_runner = "bash -c '".($self->{languages}->{$language})." && source $source_file'";
                }else{
                  $ext_runner = "bash -c 'source $source_file'";
                }
  
              }else{
                $ext_runner.= ' '.$self->{languages}->{$language} if $self->{languages}->{$language};
                $ext_runner.=' '.$source_file;
              }
  
              my $st = system("$ext_runner 2>$source_file.err 1>$source_file.out");  
  
              if ($st != 0){
                confess "$ext_runner failed, see $source_file.err for detailes";
              }
    
              $self->add_debug_result("generator OK. inline. $ext_runner") if $self->{debug_mod} >= 2;
    
              $self->validate("$source_file.out");
            
              unless ($ENV{outth_dls_keep_ext_source_code}){
                unlink("$source_file.out");
                unlink("$source_file.err");
                unlink("$source_file");
              }
    
          }

        }else {

          my $code_to_eval = join "\n", @$code;
          my $arr_ref = eval " package main; $code_to_eval";

          confess "eval error; sub:handle_generator; code:\n$code_to_print\nerror: $@" if $@;
          confess "not valid return from generator, should be ARRAYREF. got: @{[ref $arr_ref]}" unless ref($arr_ref) eq 'ARRAY' ;

          $self->add_debug_result("generator OK. multiline. $code_to_eval") if $self->{debug_mod} >= 3;
          $self->validate($arr_ref);
  
      }

    }

}

sub handle_regexp {

    my $self = shift;
    my $re = shift;
    
    my $m;

    my $reset_context = 0;

    if ($self->{within_mode}){

        $self->{within_mode} = 0; 
        $reset_context = 1;

        if ($self->{last_check_status}){
            my $lml =  $self->_short_string($self->{last_match_line});
            $m = "'$lml' match /$re/";
        } else {
            $m = "output match /$re/";
        }
    } else {
        $m = "output match /$re/";
        $m = "[b] $m" if $self->{block_mode};
    }


    $self->check_line($re, 'regexp', $m);

    $self->reset_context if $reset_context; 

    $self->add_debug_result("regexp OK. $re") if $self->{debug_mod} >= 3;


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

    $self->add_debug_result("within OK. $re") if $self->{debug_mod} >= 3;
    
}

sub handle_plain {

    my $self = shift;
    my $l = shift;

    my $m;
    my $lshort =  $self->_short_string($l);
    my $reset_context = 0;

    if ($self->{within_mode}){
        
        $self->{within_mode} = 0;
        $reset_context = 1;

        if ($self->{last_check_status}){
            my $lml =  $self->_short_string($self->{last_match_line});
            $m = "'$lml' match '$lshort'";
        } else{
            $m = "output match '$lshort'";
        }
    }else{
        $m = "output match '$lshort'";
        $m = "[b] $m" if $self->{block_mode};
    }


    $self->check_line($l, 'default', $m);

    $self->reset_context if $reset_context; 

    $self->add_debug_result("plain OK. $l") if $self->{debug_mod} >= 3;
}


sub _short_string {

    my $self = shift;
    my $str = shift;
    my $sstr = substr( $str, 0, $self->{match_l} );

    s{\r}[]g for $str;
    s{\r}[]g for $sstr;
    
    return $sstr < $str ? "$sstr ..." : $sstr; 

}

1;

__END__

=pod


=encoding utf8


=head1 NAME

Outthentic::DSL


=head1 SYNOPSIS

Language to validate text output.


=head1 Install

    $ cpanm Outthentic::DSL


=head1 Informal introduction

Alternative outthentic dsl introduction could be found L<here|https://github.com/melezhik/outthentic-dsl/blob/master/intro.md>


=head1 Glossary


=head2 Input text

An arbitrary, often unstructured text being verified. It could be any text.

Examples:

=over

=item *

html code


=item *

xml code


=item *

json 


=item *

plain text


=item *

emails :-)


=item *

http headers


=item *

another program languages code


=back


=head2 Outthentic dsl

=over

=item *

Is a language to verify I<arbitrary> plain text



=item *

Outthentic dsl is both imperative and declarative language



=back


=head3 Declarative way

You define rules ( check expressions ) to describe expected content.


=head3 Imperative way

You define a process of verification using custom perl code ( validators, generators, code expressions  ).


=head2 dsl code

A  program code written on outthentic dsl language to verify text input.


=head2 Search context

Verification process is carried out in a given I<context>.

But default search context is the same as original input text stream. 

Search context could be however changed in some conditions.


=head2 dsl parser

dsl parser is the program which:

=over

=item *

parses dsl code



=item *

parses text input



=item *

verifies text input ( line by line ) against check expressions ( line by line )



=back


=head2 Verification process

Verification process consists of matching lines of text input against check expressions.

This is schematic description of the process:

    For every check expression in check expressions list.
        Mark this check step as in unknown state.
        For every line in input text.
            Does line match check expression? Check step is marked as succeeded.
            Next line.
        End of loop.
        Is this check step marked in unknown state? Mark this check step as in failed state.  
        Next check expression.
    End of loop.
    Are all check steps succeeded? Input text is verified.
    Vise versa - input text is not verified.

A final I<presentation> of verification results should be implemented in a certain L<client|#clients> I<using> L<parser api|#parser-api> and not being defined at this scope. 

For the sake of readability a I<fake> results presentation layout is used in this document. 


=head2 Parser API

Outthentic::DSL provides program api for client applications:

    use Test::More qw{no_plan};
    
    use Outthentic::DSL;
    
    my $outh = Outthentic::DSL->new('input_text');
    
    $outh->validate('/file/with/check/expressions/','input text');
    
    
    for my $r ( @{$outh->results}){
        ok($r->{status}, $r->{message}) if $r->{type} eq 'check_expression';
        diag($r->{message}) if $r->{type} eq 'debug';
    
    }

Methods list:


=head3 new

This is constructor, create Outthentic::DSL instance. 

Obligatory parameters is:

=over

=item *

input text string 


=back

Optional parameters is passed as hashref:

=over

=item *

matchI<l - truncate matching strings to {match>l} bytes


=back

Default value is `40'

=over

=item *

debug_mod - enable debug mode

=over

=item *

Possible values is 0,1,2,3.



=item *

Set to 1 or 2 or 3 if you want to see some debug information in validation results.



=item *

Increasing debug_mod value means more low level information appeared.



=item *

Default value is `0' - means do not create debug messages.



=back



=back


=head3 validate

Perform verification process. 

Obligatory parameter is:

=over

=item *

a path to file with dsl code


=back


=head3 results


Returns validation results as arrayref containing { type, status, message } hashrefs.


=head2 Outthentic clients

Client is a external program using dsl API. Existed outthentic clients:

=over

=item *

L<Swat|https://github.com/melezhik/swat> - web application testing tool



=item *

L<Outthentic|https://github.com/melezhik/outthentic> -  multipurpose scenarios framework



=back

More clients wanted :) , please L<write me|mailto:melezhik@gmail.com> if you have one!


=head1 dsl code syntax

Outthentic dsl code comprises following entities:

=over

=item *

Check expressions:

=over

=item *

plain     strings


=item *

regular   expressions


=item *

text      blocks


=item *

within    expressions


=item *

asserts   expressions


=item *

range     expressions


=back



=item *

Comments



=item *

Blank lines



=item *

Code expressions



=item *

Generator expressions



=item *

Validator expressions



=back


=head1 Check expressions

Check expressions define patterns to match input text stream. 

Here is a simple example:

Input text:

    HELLO
    HELLO WORLD
    My birth day is: 1977-04-16

Dsl code:

    HELLO
    regexp: \d\d\d\d-\d\d-\d\d

Results:

    +--------+------------------------------+
    | status | message                      |
    +--------+------------------------------+
    | OK     | matches "HELLO"              |
    | OK     | matches /\d\d\d\d-\d\d-\d\d/ |
    +--------+------------------------------+

There are two basic types of check expressions:

=over

=item *

L<plain text expressions|#plain-text-expressions> 



=item *

L<regular expressions|#regular-expressions>.



=back


=head1 Plain text expressions 

Plain text expressions are just a lines should be I<included> at input text stream.

Dsl code:

        I am ok
        HELLO Outthentic

Input text:

    I am ok , really
    HELLO Outthentic !!!

Result - verified

Plain text expressions are case sensitive:

Input text:

    I am OK

Result - not verified


=head1 Regular expressions

Similarly to plain text matching, you may require that input lines match some regular expressions:

Dsl code:

    regexp: \d\d\d\d-\d\d-\d\d # date in format of YYYY-MM-DD
    regexp: Name: \w+ # name
    regexp: App Version Number: \d+\.\d+\.\d+ # version number

Input text:

    2001-01-02
    Name: outthentic
    App Version Number: 1.1.10

Result - verified


=head1 One or many?

Parser does not care about I<how many times> a given check expression is matched in input text.

If at least one line in a text match the check expression - I<this check> is considered as succeeded.

Parser  I<accumulate> all matching lines for given check expression, so they could be processed.

Input text:

    1 - for one
    2 - for two
    3 - for three       
    
    regexp: (\d+) for (\w+)
    code: for my $c( @{captures()}) {  print $c->[0], "/", $c->[1], "\n"}

Output:

    1/one
    2/two
    3/three

See L<"captures"|#captures> section for full explanation of a captures mechanism:


=head1 Comments, blank lines and text blocks

Comments and blank lines don't impact verification process but one could use them to improve code readability.


=head2 Comments

Comment lines start with `#' symbol, comments chunks are ignored by parser.

Dsl code:

    # comments could be represented at a distinct line, like here
    The beginning of story
    Hello World # or could be added for the existed expression to the right, like here


=head2 Blank lines

Blank lines are ignored as well.

Dsl code:

    # every story has the beginning
    The beginning of a story
    # then 2 blank lines
    
    
    # end has the end
    The end of a story

But you B<can't ignore> blank lines in a `text block' context ( see `text blocks' subsection ).

Use `:blank_line' marker to match blank lines.

Dsl code:

    # :blank_line marker matches blank lines
    # this is especially useful
    # when match in text blocks context:
    
    begin:
        this line followed by 2 blank lines
        :blank_line
        :blank_line
    end:


=head2 Text blocks

Sometimes it is very helpful to match against a `sequence of lines' like here.

Dsl code:

    # this text block
    # consists of 5 strings
    # going consecutive
    
    begin:
        # plain strings
        this string followed by
        that string followed by
        another one
        # regexps patterns:
        regexp: with (this|that)
        # and the last one in a block
        at the very end
    end:

Input text:

    this string followed by
    that string followed by
    another one string
    with that string
    at the very end.

Result - verified

Input text:

    that string followed by
    this string followed by
    another one string
    with that string
    at the very end.

Result - not verified

`begin:' `end:' markers decorate `text blocks' content. 

Markers should not be followed by any text at the same line.


=head2 Don't forget to close the block ...

Be aware if you leave "dangling" `begin:' marker without closing `end': somewhere else 
parser will remain in a `text block' mode till the end of the file, which is probably not you want:

Dsl code:

        begin:
            here we begin
            and till the very end of test
    
            we are in `text block` mode


=head1 Code expressions

Code expressions are just a pieces of 'some language code' you may inline and execute B<during parsing> process.

By default, if I<language> is no set Perl language is assumed. Here is example:

Dsl code:

    # Perl expression 
    # between two check expressions
    Once upon a time
    code: print "hello I am Outthentic"
    Lived a boy called Outthentic

Output:

    hello I am Outthentic

Internally once dsl code gets parsed it is "turned" into regular Perl code:

    execute_check_expression("Once upon a time");
    eval 'print "Lived a boy called Outthentic"';
    execute_check_expression("Lived a boy called Outthentic");

When use Perl expressions be aware of:

=over

=item *

Perl expressions are executed by Perl eval function in context of C<package main>, please be aware of that.



=item *

Follow L<http://perldoc.perl.org/functions/eval.html|http://perldoc.perl.org/functions/eval.html> to know more about Perl eval function.



=back

One may use other languages in code expressions. Use should use `here' document style ( see L<multiline expressions|#Multiline> section ) to insert your code and
set shebang to define a language. Here are some examples:

=over

=item *

bash 

code:  <<HERE
!bash

echo '# hello I am Outthentic'
HERE



=item *

ruby

code: <<CODE
!ruby

puts '# hello I am Outthentic'
CODE



=back


=head1 Asserts

Asserts are simple statements with one of two values : true|false, a second assert parameter is just a description.

Dsl code

    assert: 0 'this is not true'
    assert: 1 'this is true'

Asserts almost always are created dynamically with generators. See next section.


=head1 Generators

=over

=item *

Generators is the way to I<generate new outthentic entries on the fly>.



=item *

Generator expressions like code expressions are just a piece of code to be executed.



=item *

The only requirement for generator code - it should return I<new outthentic entities>.



=item *

If you use Perl in generator expressions ( which is by default ) - last statement in your
code should return reference to array of strings. Strings in array would I<represent> a I<new> outthentic entities.



=item *

If you use not Perl language in generator expressions to produce new outthentic entities you should print them
into B<stdout>. See examples below.



=item *

A new outthentic entries are passed back to parser and executed immediately.



=back

Generators expressions start with `:generator' marker.

Here is simple example.

Dsl code:

    # original check list
    
    Say
    HELLO
     
    # this generator creates 3 new check expressions:
    
    generator: <<CODE
    [ 
      'say', 
      'hello', 
      'again'
    ]
    CODE

Updated check list:

    Say
    HELLO
    say
    hello
    again

If you use not Perl in generator expressions, you have to print entries into stdout instead of returning
and array reference like in Perl. Here is more examples for other languages:

    generator: <<CODE
    !bash
      echo say
      echo hello
      echo again
    CODE
    
    generator: <<CODE
    !ruby
      puts 'say'
      puts 'hello'
      puts 'again'
    CODE

Here is more complicated example using Perl.

Dsl code:

    # this generator generates
    # comment lines
    # and plain string check expressions:
    
    generator: <<CODE    
    my %d = { 
      'foo' => 'foo value', 
      'bar' => 'bar value' 
    };     
    [ 
      map  { 
        ( "# $_", "$data{$_}" )  
      } keys %d 
    ]
    CODE

Updated check list:

    # foo
    foo value
    # bar
    bar value

Generators could produce not only check expressions but code expressions and ... another generators.

This is fictional example.

Input Text:

    A
    AA
    AAA
    AAAA
    AAAAA

Dsl code:

    generator:  <<CODE
    sub next_number {                       
        my $i = shift;                       
        $i++;                               
        return [] if $i>=5;                 
        [                                   
            'regexp: ^'.('A' x $i).'$'      
            "generator: next_number($i)"     
        ]  
    }
    CODE

Generators are commonly used to create an asserts.

Input:

    number: 10

Dsl code:

    number: (\d+)
    
    generator: <<CODE
    !ruby
      puts "assert: #{capture()[0] == 10}, you've got 10!"  
    CODE


=head1 Validators

WARNING!!! You should prefer asserts over validators. Validators feature will be deprecated soon!

Validator expressions are perl code expressions used for dynamic verification.

Validator expressions start with `validator:' marker.

A Perl code inside validator block should I<return> array reference. 

=over

=item *

Once code is executed a returned array structure treated as:



=item *

first element - is a status number ( Perl true or false )



=item *

second element - is a helpful message 



=back

Validators a kind of check expressions with check logic I<expressed> in program code. Here is examples:

Dsl code:

    # this is always true
    validator: [ 10>1 , 'ten is bigger then one' ]
    
    # and this is not
    validator: [ 1>10, 'one is bigger then ten'  ]
    
    # this one depends on previous check
    regexp: credit card number: (\d+)
    validator: [ captures()->[0]-[0] == '0101010101', 'I know your secrets!'  ]
    
    
    # and this could be any
    validator: [ int(rand(2)) > 1, 'I am lucky!'  ]

Validators are often used with the L<`captures expressions'|#captures>. This is another example.

Input text:

    # my family ages list
    alex    38
    julia   32
    jan     2

Dsl code:

    # let's capture name and age chunks
    regexp: /(\w+)\s+(\d+)/
    
    validator: <<CODE
    my $total=0;                        
    for my $c (@{captures()}) {         
        $total+=$c->[0];                
    }                                   
    [ ( $total == 72 ), "total age" ] 
    
    CODE


=head1 Multiline expressions


=head2 Multilines in check expressions

When parser parses check expressions it does it in a I<single line mode> :

=over

=item *

a check expression is always single line string



=item *

input text is parsed in line by line mode, thus every line is validated against a single line check expression



=back

Example.

    # Input text
    
    Multiline
    string
    here

Dsl code:

    # check list
    # consists of
    # single line entries
    
    Multiline
    string
    here
    regexp: Multiline \n string \n here

Results:

    +--------+---------------------------------------+
    | status | message                               |
    +--------+---------------------------------------+
    | OK     | matches "Multiline"                   |
    | OK     | matches "string"                      |
    | OK     | matches "here"                        |
    | FAIL   | matches /Multiline \n string \n here/ |
    +--------+---------------------------------------+

Use text blocks if you want to I<represent> multiline checks.


=head2 Multilines in code expressions, generators and validators

Perl expressions, validators and generators could contain multilines expressions

There are two ways to write multiline expressions:

=over

=item *

using C<\> delimiters to split multiline string to many chunks



=item *

using HERE documents expressions 



=back


=head3 Back slash delimiters

`\' delimiters breaks a single line text on a multi lines.

Example:

    # What about to validate stdout
    # With sqlite database entries?
    
    generator:                                                          \
    
    use DBI;                                                            \
    my $dbh = DBI->connect("dbi:SQLite:dbname=t/data/test.db","","");   \
    my $sth = $dbh->prepare("SELECT name from users");                  \
    $sth->execute();                                                    \
    my $results = $sth->fetchall_arrayref;                              \
    
    [ map { $_->[0] } @${results} ]


=head3 HERE documents expressions 

Is alternative to make your multiline code more readable:

    # What about to validate stdout
    # With sqlite database entries?
    
    generator: <<CODE
    
    use DBI;                                                            
    my $dbh = DBI->connect("dbi:SQLite:dbname=t/data/test.db","","");   
    my $sth = $dbh->prepare("SELECT name from users");                  
    $sth->execute();                                                    
    my $results = $sth->fetchall_arrayref;                              
    
    [ map { $_->[0] } @${results} ]
    
    CODE


=head1 Captures

Captures are pieces of data get captured when parser validate lines against a regular expressions:

Input text:

    # my family ages list.
    alex    38
    julia   32
    jan     2
    
    
    # let's capture name and age chunks
    regexp: /(\w+)\s+(\d+)/
    code:                                   \
        for my $c (@{captures}){            \
            print "name:", $c->[0], "\n";   \
            print "age:", $c->[1], "\n";    \
        }    

Data accessible via captures():

    [
        ['alex',    38 ]
        ['julia',   32 ]
        ['jan',     2  ]
    ]

Then captured data usually good fit for validators extra checks.

Dsl code

    validator: << CODE
    my $total=0;                        
    for my $c (@{captures()}) {         
        $total+=$c->[0];                
    }                                   
    [ ($total == 72 ), "total age of my family" ];
    
    CODE


=head2 captures() function

captures() function returns an array reference holding all chunks captured during I<latest regular expression check>.

Here some more examples.

Dsl code:

    # check if stdout contains numbers,
    # then calculate total amount
    # and check if it is greater then 10
    
    regexp: (\d+)
    
    validator:  <<CODE
    my $total=0;                        
    for my $c (@{captures()}) {         
        $total+=$c->[0];                
    }                                   
    [ ( $total > 10 ) "total amount is greater than 10" ]
    
    CODE
    
    
    # check if stdout contains lines
    # with date formatted as date: YYYY-MM-DD
    # and then check if first date found is yesterday
    
    regexp: date: (\d\d\d\d)-(\d\d)-(\d\d)
    
    validator:  <<CODE
    use DateTime;                       
    my $c = captures()->[0];            
    my $dt = DateTime->new( year => $c->[0], month => $c->[1], day => $c->[2]  ); 
    my $yesterday = DateTime->now->subtract( days =>  1 );                        
    
    [ ( DateTime->compare($dt, $yesterday) == 0 ),"first day found is - $dt and this is a yesterday" ];
    
    CODE


=head2 capture() function

capture() function returns a I<first element> of captures array. 

it is useful when you need data I<related> only  I<first> successfully matched line.

Dsl code:

    # check if  text contains numbers
    # a first number should be greater then ten
    
    regexp: (\d+)
    validator: [ ( capture()->[0] >  10 ), " first number is greater than 10 " ];


=head1 Search context modificators

Search context modificators are special check expressions which not only validate text but modify search context.

By default search context is equal to original input text stream. 

That means parser executes validation use all the lines when performing checks 

However there are two search context modificators to change this behavior:

=over

=item *

within expressions



=item *

range expressions



=back


=head2 Within expressions

Within expression acts like regular expression - checks text against given patterns 

Text input:

    These are my colors
    
    color: red
    color: green
    color: blue
    color: brown
    color: back
    
    That is it!

Dsl code:

    # I need one of 3 colors:
    
    within: color: (red|green|blue)

Then if checks given by within statement succeed I<next> checks will be executed I<in a context of> succeeded lines:

    # but I really need a green one
    green

The code above does follows:

=over

=item *

try to validate input text against regular expression "color: (red|green|blue)"



=item *

if validation is successful new search context is set to all I<matching> lines



=back

These are:

    color: red
    color: green
    color: blue

=over

=item *

thus next plain string checks expression will be executed against new search context


=back

Results:

    +--------+------------------------------------------------+
    | status | message                                        |
    +--------+------------------------------------------------+
    | OK     | matches /color: (red|green|blue)/              |
    | OK     | /color: (red|green|blue)/ matches green        |
    +--------+------------------------------------------------+

Here more examples:

    # try to find a date string in following format
    within: date: \d\d\d\d-\d\d-\d\d
    
    # we only need a dates in 2000 year
    2000-

Within expressions could be sequential, which effectively means using `&&' logical operators for within expressions:

    # try to find a date string in following format
    within: date: \d\d\d\d-\d\d-\d\d
    
    # and try to find year of 2000 in a date string
    within: 2000-\d\d-\d\d
    
    # and try to find month 04 in a date string
    within: \d\d\d\d-04-\d\d

Speaking in human language chained within expressions acts like I<specifications>. 

When you may start with some generic assumptions and then make your requirements more specific. A failure on any step of chain results in
immediate break. 


=head1 Range expressions

Range expressions also act like I<search context modificators> - they change search area to one included
I<between> lines matching right and left regular expression of between statement.

It is very similar to what Perl L<range operator|http://perldoc.perl.org/perlop.html#Range-Operators> does 
when extracting pieces of lines inside stream:

    while (<STDOUT>){
        if /foo/ ... /bar/
    }

Outthentic analogy for this is range expression:

    between: foo bar

Between statement takes 2 arguments - left and right regular expression to setup search area boundaries.

A search context will be all the lines included between line matching left expression and line matching right expression.

A matching (boundary) lines are not included in range. 

These are few examples:

Parsing html output

Input text:

    <table cols=10 rows=10>
        <tr>
            <td>one</td>
        </tr>
        <tr>
            <td>two</td>
        </tr>
        <tr>
            <td>the</td>
        </tr>
    </table>

Dsl code:

    # between expression:
    between: <table.*> <\/table>
    regexp: <td>(\S+)<\/td>
    
    # or even so
    between: <tr.*> <\/tr>
    regexp: <td>(\S+)<\/td>


=head2 Multiple range expressions

Multiple range expressions could not be nested, every new between statement discards old search context and setup new one:

Input text:

    foo
    
        1
        2
        3
    
        FOO
            100
        BAR
    
    bar
    
    FOO
    
        10
        20
        30
    
    BAR

Dsl code:

    between: foo bar
    
    code: print "# foo/bar start"
    
    # here will be everything
    # between foo and bar lines
    
    regexp: \d+
    
    code: <<CODE                           
    for my $i (@{captures()}) {     
        print "# ", $i->[0], "\n"   
    }                               
    print "# foo/bar end"
    
    CODE
    
    between: FOO BAR
    
    code: print "# FOO/BAR start"
    
    # here will be everything
    # between FOO and BAR lines
    # NOT necessarily inside foo bar block
    
    regexp: \d+
    
    code:  <<CODE
    for my $i (@{captures()}) {     
        print "#", $i->[0], "\n";   
    }                               
    print "# FOO/BAR end"
    
    CODE

Output:

        # foo/bar start
        # 1
        # 2
        # 3
        # 100
        # foo/bar end
    
        # FOO/BAR start
        # 100
        # 10
        # 20
        # 30
        # FOO/BAR end


=head2 Restoring search context

And finally to restore search context use `reset_context:' statement.

Input text:

    hello
    foo
        hello
        hello
    bar

Dsl code:

    between foo bar
    
    # all check expressions here
    # will be applied to the chunks
    # between /foo/ ... /bar/
    
    hello       # should match 2 times
    
    # if you want to get back to an original search context
    # just say reset_context:
    
    reset_context:
    hello       # should match three times


=head2 Range expressions caveats


=head3 Range expressions can't verify continuous lists.

That means range expression only verifies that there are I<some set> of lines inside some range.
It is not necessary should be continuous.

Example.

Input text:

    foo
        1
        a
        2
        b
        3
        c
    bar

Dsl code:

    between: foo bar
        1
        code: print capture()->[0], "\n"
        2
        code: print capture()->[0], "\n"
        3
        code: print capture()->[0], "\n"

Output:

        1 
        2 
        3 

If you need check continuous sequences checks use text blocks.


=head1 Experimental features

Below is highly experimental features purely tested. You may use it on your own risk! ;)


=head2 Streams

Streams are alternative for captures. Consider following example.

Input text:

    foo
        a
        b
        c
    bar
    
    foo
        1
        2
        3
    bar
    
    foo
        0
        00
        000
    bar

Dsl code:

    begin:
    
        foo
    
            regexp: (\S+)
            code: print '#', ( join ' ', map {$_->[0]} @{captures()} ), "\n"
    
            regexp: (\S+)
            code: print '#', ( join ' ', map {$_->[0]} @{captures()} ), "\n"
    
            regexp: (\S+)
            code: print '#', ( join ' ', map {$_->[0]} @{captures()} ), "\n"
    
    
        bar
    
    end:

Output:

    # a 1 0
    # b 2 00
    # c 3 000

Notice something interesting? Output direction has been inverted.

The reason for this is outthentic check expression works in "line by line scanning" mode 
when text input gets verified line by line against given check expression. 

Once all lines are matched they get dropped into one heap without preserving original "group context". 

What if we would like to print all matching lines grouped by text blocks they belong to?

As it's more convenient way ...

This is where streams feature comes to rescue.

Streams - are all the data successfully matched for given I<group context>. 

Streams are I<applicable> for text blocks and range expressions.

Let's rewrite last example.

Dsl code:

    begin:
    
        foo
            regexp: \S+
            regexp: \S+
            regexp: \S+
        bar
    
        code:  <<CODE
            for my $s (@{stream()}) {           
                print "# ";                     
                for my $i (@{$s}){              
                    print $i;                   
                }                               
                print "\n";                     
            }
    
    CODE
    
    end:

Stream function returns an arrays of I<streams>. Every stream holds all the matched lines for given I<logical block>.

Streams preserve group context. Number of streams relates to the number of successfully matched groups.

Streams data presentation is much closer to what was originally given in text input:

Output:

    # foo a b  c    bar
    # foo 1 2  3    bar
    # foo 0 00 000  bar

Stream could be specially useful when combined with range expressions of I<various> ranges lengths.

For example.

Input text:

    foo
        2
        4
        6
        8
    bar
    
    foo
        1
        3
    bar
    
    foo
        0
        0
        0
    bar

Dsl code:

    between: foo bar
    
    regexp: \d+
    
    code:  <<CODE
        for my $s (@{stream()}) {           
            print "# ";                     
            for my $i (@{$s}){              
                print $i;                   
            }                               
            print "\n";                     
        }
    
    CODE

Output:

    # 2 4 6 8
    # 1 3
    # 0 0 0


=head1 Author

L<Aleksei Melezhik|mailto:melezhik@gmail.com>


=head1 Home page

https://github.com/melezhik/outthentic-dsl


=head1 COPYRIGHT

Copyright 2015 Alexey Melezhik.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


=head1 See also

Alternative outthentic dsl introduction could be found here - L<intro.md|https://github.com/melezhik/outthentic-dsl/blob/master/intro.md>


=head1 Thanks

=over

=item *

To God as the One Who inspires me to do my job!


=back
