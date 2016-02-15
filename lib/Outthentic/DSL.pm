package Outthentic::DSL;

use strict;

our $VERSION = '0.0.6';

use Carp;
use Data::Dumper;
use Outthentic::DSL::Context::Range;
use Outthentic::DSL::Context::Default;
use Outthentic::DSL::Context::TextBlock;

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
        if $self->{debug_mod} >=1;
        
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


    LINE: for my $l (@lines){

        chomp $l;

        $self->add_debug_result("[dsl] $l") if $self->{debug_mod} >= 2;

        next LINE unless $l =~ /\S/; # skip blank lines

        next LINE if $l=~ /^\s*#(.*)/; # skip comments

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
            confess "unterminated multiline $chunk_type found, last line: $multiline_chunk[-1]" if defined($chunk_type);
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

        }elsif($l=~/^\s*validator:\s*(.*)/){ # `validator' line

            my $code = $1;

            if ($code=~s/\\\s*$//){
                 push @multiline_chunk, $code;
                 $chunk_type = 'validator';
                 next LINE; # this is multiline chunk, accumulate lines until meet '\' line

            }else{
                $self->handle_validator($code);
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

            confess "you can't switch to within mode when text block mode is enabled" 
                if $self->{block_mode};

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

    confess "unterminated multiline $chunk_type found, last line: $multiline_chunk[-1]" if defined($chunk_type);

}

sub handle_code {

    my $self = shift;
    my $code = shift;

    unless (ref $code){
        eval "package main; $code;";
        confess "eval error; sub:handle_code; code:$code; error: $@" if $@;
        $self->add_debug_result("handle_code OK. $code") if $self->{debug_mod} >= 3;
    } else {
        my $code_to_eval = join "\n", @$code;
        eval "package main; $code_to_eval";
        confess "eval error; sub:handle_code; code:$code_to_eval; error: $@" if $@;
        $self->add_debug_result("handle_code OK. multiline. $code_to_eval") if $self->{debug_mod} >= 3;
    }

}

sub handle_validator {

    my $self = shift;
    my $code = shift;

    unless (ref $code){
        my $r = eval "package main; $code;";
        confess "eval error; sub:handle_validator; code:$code; error: $@" if $@;
        confess "not valid return from validator, should be ARRAYREF. got: @{[ref $r]}" unless ref($r) eq 'ARRAY' ;
        $self->add_result({ status => $r->[0] , message => $r->[1] });
        $self->add_debug_result("handle_validator OK (status: $r->[0] message: $r->[1]). $code") if $self->{debug_mod} >= 2;
    } else {
        my $code_to_eval = join "\n", @$code;
        my $r = eval "package main; $code_to_eval";
        confess "eval error; sub:handle_validator; code:$code_to_eval; error: $@" if $@;
        confess "not valid return from validator, should be ARRAYREF. got: @{[ref $r]}" unless ref($r) eq 'ARRAY' ;
        $self->add_result({ status => $r->[0] , message => $r->[1] });
        $self->add_debug_result("handle_validator OK. multiline. $code_to_eval") if $self->{debug_mod} >= 2;
    }

}

sub handle_generator {

    my $self = shift;
    my $code = shift;

    unless (ref $code){
        my $arr_ref = eval "package main; $code";
        confess "eval error; sub:handle_generator; code:$code; error: $@" if $@;
        confess "not valid return from generator, should be ARRAYREF. got: @{[ref $arr_ref]}" unless ref($arr_ref) eq 'ARRAY' ;
        $self->add_debug_result("handle_generator OK. $code") if $self->{debug_mod} >= 3;
        $self->validate($arr_ref);
    } else {
        my $code_to_eval = join "\n", @$code;
        my $arr_ref = eval " package main; $code_to_eval";
        confess "eval error; sub:handle_generator; code:$code_to_eval; error: $@" if $@;
        confess "not valid return from generator, should be ARRAYREF. got: @{[ref $arr_ref]}" unless ref($arr_ref) eq 'ARRAY' ;
        $self->add_debug_result("handle_generator OK. multiline. $code_to_eval") if $self->{debug_mod} >= 3;
        $self->validate($arr_ref);
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

    $self->add_debug_result("handle_regexp OK. $re") if $self->{debug_mod} >= 3;


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

    $self->add_debug_result("handle_within OK. $re") if $self->{debug_mod} >= 3;
    
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

    $self->add_debug_result("handle_plain OK. $l") if $self->{debug_mod} >= 3;
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


=head1 SYNOPSIS

Language to validate text output.


=head1 Install

    cpanm Outthentic::DSL


=head1 Informal introduction

Alternative introduction into outthentic dsl in more in infromal way could be found here 
- L<intro.md|https://github.com/melezhik/outthentic-dsl/blob/master/intro.md>


=head1 Glossary


=head2 Outthentic DSL 

=over

=item *

Is a language to validate I<arbitrary> plain text. Very often a short form `DSL' is used for this term. 



=item *

Outthentic DSL is both imperative and declarative language.



=back


=head2 Check files

A plain text files containing program code written on DSL to describe text L<validation process|#validation-process>.


=head2 Code

Content of check file. Should be program code written on DSL.


=head2 Stdout

It's convenient to refer to the text validate by as stdout, thinking that one program generates and yields output into stdout
which is then validated.


=head2 Search context

A synonym for stdout term with emphasis of the fact that validation process if carried out in a given context.

But default search context is equal to original stdout stream. 

Parser verifies all stdout against a list of check expressions. 

But see L<search context modificators|#search-context-modificators> section.


=head2 Parser

Parser is the program which:

=over

=item *

parses check file line by line



=item *

creates and then I<executes> outthentic entries represented by parsed lines



=item *

execution of each entry results in one of three things:

=over

=item *

performing L<validation|#validation> process if entry is check expression one



=item *

generating new outthentic entries if entry is generator one



=item *

execution of Perl code if entry is Perl expression one



=back



=back


=head2 Validation process

Validation process consists of: 

=over

=item *

checking if stdout matches the check expression or



=item *

in case of L<validator expression|#validators> :

=over

=item *

executing validator code and checking if returned value is true 


=back



=item *

generating validation results could be retrieved later



=item *

a final I<presentation> of validation results should be implemented in a certain L<client|#clients> I<using> L<parser api|#parser-api> and not being defined at DSL scope. For the sake of readability a table like form ( which is a fake one ) is used for validation results in this document. 



=back


=head2 Parser API

Outthentic provides program api for parser:

    use Test::More qw{no_plan};
    
    use Outthentic::DSL;
    
    my $outh = Outthentic::DSL->new('stdout string', $opts);
    $outh->validate('path/to/check/file','stdout string');
    
    
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

stdout string 


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

Runs parser for check file and and initiates validation process against stdout.

Obligatory parameter is:

=over

=item *

path to check file


=back


=head3 results


Returns validation results as arrayref containing { type, status, message } hashrefs.


=head2 Outthentic client

Client is a external program using DSL API. Existed outthentic clients:

=over

=item *

L<swat|https://github.com/melezhik/swat>


=item *

L<outthentic|https://github.com/melezhik/outthentic>


=back

More clients wanted :) , please L<write me|mailto:melezhik@gmail.com> if you have one!


=head1 Outthentic entities

Outthentic DSL comprises following basic entities:

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

range     expressions


=item *

validator expressions


=back



=item *

Comments



=item *

Blank lines



=item *

Perl expressions



=item *

Generator expressions



=back


=head1 Check expressions

Check expressions defines I<lines stdout should match>. Here is a simple example:

    # stdout
    
    HELLO
    HELLO WORLD
    My birth day is: 1977-04-16
    
    
    # check list
    
    HELLO
    regexp: \d\d\d\d-\d\d-\d\d
    
    
    # validation results
    
    +--------+------------------------------+
    | status | message                      |
    +--------+------------------------------+
    | OK     | matches "HELLO"              |
    | OK     | matches /\d\d\d\d-\d\d-\d\d/ |
    +--------+------------------------------+

There are two basic types of check expressions - L<plain strings|#plain-strings> and L<regular expressions|#regular-expressions>.

It is convenient to talk about I<check list> as of all check expressions in a given check file.


=head1 Plain string expressions 

        I am ok
        HELLO Outthentic

The code above declares that stdout should have lines 'I am ok' and 'HELLO Outthentic'.


=head1 Regular expressions

Similarly to plain strings matching, you may require that stdout has lines matching the regular expressions:

    regexp: \d\d\d\d-\d\d-\d\d # date in format of YYYY-MM-DD
    regexp: Name: \w+ # name
    regexp: App Version Number: \d+\.\d+\.\d+ # version number

Regular expressions should start with `regexp:' marker.


=head1 One or many?

Parser does not care about I<how many times> a given check expression is found in stdout.

It's only required that at least one line in stdout match the check expression ( this is not the case with text blocks, see later )

However it's possible to I<accumulate> all matching lines and save them for further processing:

    regexp: (Hello, my name is (\w+))

See L<"captures"|#captures> section for full explanation of a captures mechanism:


=head1 Comments, blank lines and text blocks

Comments and blank lines don't impact validation process but one could use them to improve code readability.


=head2 Comments

Comment lines start with `#' symbol, comments chunks are ignored by parser:

    # comments could be represented at a distinct line, like here
    The beginning of story
    Hello World # or could be added for the existed expression to the right, like here


=head2 Blank lines

Blank lines are ignored as well:

    # every story has the beginning
    The beginning of a story
    # then 2 blank lines
    
    
    # end has the end
    The end of a story

But you B<can't ignore> blank lines in a `text block matching' context ( see `text blocks' subsection ), use `:blank_line' marker to match blank lines:

    # :blank_line marker matches blank lines
    # this is especially useful
    # when match in text blocks context:
    
    begin:
        this line followed by 2 blank lines
        :blank_line
        :blank_line
    end:


=head2 Text blocks

Sometimes it is very helpful to match a stdout against a `block of strings' goes consequentially, like here:

    # this text block
    # consists of 5 strings
    # goes consequentially
    # line by line:
    
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

This validation will succeed when gets executed against this chunk:

    this string followed by
    that string followed by
    another one string
    with that string
    at the very end.

But B<will not> for this chunk:

    that string followed by
    this string followed by
    another one string
    with that string
    at the very end.

`begin:' `end:' markers decorate `text blocks' content. `:being|:end' markers should not be followed by any text at the same line.

Also be aware if you leave "dangling" `begin:' marker without closing `end': somewhere else

Parser will remain in a `text block' mode till the end of check file, which is probably not you want:

        begin:
            here we begin
            and till the very end of test
    
            we are in `text block` mode


=head1 Perl expressions

Perl expressions are just a pieces of Perl code to I<get evaled> during parsing process. This is how it works:

    # Perl expression between two check expressions
    Once upon a time
    code: print "hello I am Outthentic"
    Lived a boy called Outthentic

Internally once check file gets parsed this piece of DSL code is "turned" into regular Perl code:

    execute_check_expression("Once upon a time");
    eval 'print "Lived a boy called Outthentic"';
    execute_check_expression("Lived a boy called Outthentic");

One of the use case for Perl expressions is to store L<`captures'|#captures> data:

    regexp: my name is (\w+) and my age is (\d+)
    code: $main::data{name} = capture()->[0]; $main::data{age} = capture()->[1]; 

=over

=item *

Perl expressions are executed by Perl eval function in context of C<package main>, please be aware of that.



=item *

Follow L<http://perldoc.perl.org/functions/eval.html|http://perldoc.perl.org/functions/eval.html> to get know more about Perl eval.



=back


=head1 Validators

=over

=item *

Validator expressions like Perl expressions are just a piece of Perl code. 



=item *

Validator expressions start with `validator:' marker



=item *

Validator code gets executed and value returned by the code is treated as validation status.



=item *

Validator should return array reference. First element of array is validation status and second one is helpful message which
will be shown when status is appeared in TAP output.



=back

For example:

    # this is always true
    validator: [ 10>1 , 'ten is bigger then one' ]
    
    # and this is not
    validator: [ 1>10, 'one is bigger then ten'  ]

=over

=item *

Validators become very efficient when gets combined with L<`captures expressions'|#captures>


=back

This is a simple example:

    # stdout
    # it's my family ages.
    alex    38
    julia   32
    jan     2
    
    
    # let's capture name and age chunks
    regexp: /(\w+)\s+(\d+)/
    
    validator:                          \
    my $total=0;                        \
    for my $c (@{captures()}) {         \
        $total+=$c->[0];                \
    }                                   \
    [ ( $total == 72 ), "total age" ] 


=head1 Generators

=over

=item *

Generators is the way to I<generate new outthentic entries on the fly>.



=item *

Generator expressions like Perl expressions are just a piece of Perl code.



=item *

The only requirement for generator code - it should return I<reference to array of strings>.



=item *

Strings in array returned by generator code I<represent> new outthentic entities.



=item *

An array items are passed back to parser, so parser generate news outthentic entities and execute them.



=item *

Generators expressions start with `:generator' marker.



=back

Here is simple example:

    # original check list
    
    Say
    HELLO
     
    # this generator creates 3 new check expressions:
    
    generator: [ qw{ say hello again } ]
    
    
    # final check list:
    
    Say
    HELLO
    say
    hello
    again

Here is more complicated example:

    # this generator generates
    # comment lines
    # and plain string check expressions:
    
    generator: my %d = { 'foo' => 'foo value', 'bar' => 'bar value' }; [ map  { ( "# $_", "$data{$_}" )  } keys %d ]
    
    # generated entries:
    
    # foo
    foo value
    # bar
    bar value


=head1 Multiline expressions

When generate and execute check expressions parser operates in a I<single line mode> :

=over

=item *

check expressions are treated as single line strings


=item *

stdout is validated by given check expression in line by line way


=back

For example:

    # check list
    # consists of
    # single line entries
    
    Multiline
    string
    here
    regexp: Multiline \n string \n here
    
    # stdout
    Multiline
    string
    here
     
     # validation results
    
    +--------+---------------------------------------+
    | status | message                               |
    +--------+---------------------------------------+
    | OK     | matches "Multiline"                   |
    | OK     | matches "string"                      |
    | OK     | matches "here"                        |
    | FAIL   | matches /Multiline \n string \n here/ |
    +--------+---------------------------------------+

Use text blocks if you want to achieve multiline checks.

However when writing Perl expressions, validators or generators one could use multilines strings.

`\' delimiters breaks a single line text on a multi lines:

    # What about to validate stdout
    # With sqlite database entries?
    
    generator:                                                          \
    
    use DBI;                                                            \
    my $dbh = DBI->connect("dbi:SQLite:dbname=t/data/test.db","","");   \
    my $sth = $dbh->prepare("SELECT name from users");                  \
    $sth->execute();                                                    \
    my $results = $sth->fetchall_arrayref;                              \
    
    [ map { $_->[0] } @${results} ]


=head1 Captures

Captures are pieces of data get captured when parser validates stdout against a regular expressions:

    # stdout
    # it's my family ages.
    alex    38
    julia   32
    jan     2
    
    
    # let's capture name and age chunks
    regexp: /(\w+)\s+(\d+)/

I<After> this regular expression check gets executed captured data will stored into a array:

    [
        ['alex',    38 ]
        ['julia',   32 ]
        ['jan',     2  ]
    ]

Then captured data might be accessed for example by code generator to define some extra checks:

    validator:                          \
    my $total=0;                        \
    for my $c (@{captures()}) {         \
        $total+=$c->[0];                \
    }                                   \
    [ ($total == 72 ), "total age of my family" ];

=over

=item *

`captures()' function is used to access captured data array,



=item *

it returns an array reference holding all chunks captured during I<latest regular expression check>.



=back

Here some more examples:

    # check if stdout contains numbers,
    # then calculate total amount
    # and check if it is greater then 10
    
    regexp: (\d+)
    
    validator:                          \
    my $total=0;                        \
    for my $c (@{captures()}) {         \
        $total+=$c->[0];                \
    }                                   \
    [ ( $total > 10 ) "total amount is greater than 10" ]
    
    
    # check if stdout contains lines
    # with date formatted as date: YYYY-MM-DD
    # and then check if first date found is yesterday
    
    regexp: date: (\d\d\d\d)-(\d\d)-(\d\d)
    
    validator:                          \
    use DateTime;                       \
    my $c = captures()->[0];            \
    my $dt = DateTime->new( year => $c->[0], month => $c->[1], day => $c->[2]  ); \
    my $yesterday = DateTime->now->subtract( days =>  1 );                        \
    
    [ ( DateTime->compare($dt, $yesterday) == 0 ),"first day found is - $dt and this is a yesterday" ];

You also may use `capture()' function to get a I<first element> of captures array:

    # check if stdout contains numbers
    # a first number should be greater then ten
    
    regexp: (\d+)
    validator: [ ( capture()->[0] >  10 ), " first number is greater than 10 " ];


=head1 Search context modificators

Search context modificators are special check expressions which not only validate stdout but modify search context.

But default search context is equal to original stdout. 

That means outthentic parser execute validation process against original stdout stream

There are two search context modificators to change this behavior:

=over

=item *

within expressions



=item *

range expressions



=back


=head2 Within expressions

Within expression acts like regular expression - parser checks stdout against given pattern 

    # stdout
    
    These are my colors
    
    color: red
    color: green
    color: blue
    color: brown
    color: back
    
    That is it!
    
    # outthentic check
    
    # I need one of 3 colors:
    
    within: color: (red|green|blue)

Then if checks given by within statement succeed I<next> checks will be executed I<in a context of>
succeeded lines:

    # but I really need a green one
    green

The code above does follows:

=over

=item *

try to validate stdout against regular expression "color: (red|green|blue)"



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

The result will be:

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

Speaking in human language chained within expressions acts like specifications. When you may start with some
generic assumptions and then make your requirements more specific. A failure on any step of chain results in
immediate break. 


=head1 Range expressions

Between or range expressions also act like I<search context modificators> - they change search area to one included
I<between> lines matching right and left regular expression of between statement.

It is very similar to what Perl L<range operator|http://perldoc.perl.org/perlop.html#Range-Operators> does 
when extracting pieces of lines inside stream

    while (<STDOUT>){
        if /foo/ ... /bar/
    }

Outthentic analogy for this is between expression:

    between: foo bar

Between expression takes 2 arguments - left and right regular expression to setup search area boundaries.

A search context will be all the lines included between line matching left expression and line matching right expression.

A matching (boundary) lines are not included in range:

These are few examples:

Parsing html output

    # stdout
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
    
    
    # between expression:
    between: <table.*> <\/table>
    regexp: <td>(\S+)<\/td>
    
    # or even so
    between: <tr.*> <\/tr>
    regexp: <td>(\S+)<\/td>

Between expressions could not be nested, every new between expression discards old search context
and setup new one:

    # sample stdout
    
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
    
    # outthentic check list:
    
    between: foo bar
    
    code: print "# foo/bar start"
    
    # here will be everything
    # between foo and bar lines
    
    regexp: \d+
    
    code:                           \
    for my $i (@{captures()}) {     \
        print "# ", $i->[0], "\n"   \
    }                               \
    print "foo/bar end"
    
    between: FOO BAR
    
    code: print "# FOO/BAR start"
    
    # here will be everything
    # between FOO and BAR lines
    # NOT necessarily inside foo bar block
    
    regexp: \d+
    
    code:                           \
    for my $i (@{captures()}) {     \
        print "#", $i->[0], "\n";   \
    }                               \
    print "# FOO/BAR end"
    
    # TAP output
    
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

And finally to restore search context use `reset_context:' statement:

    # stdout
    
    hello
    foo
        hello
        hello
    bar
    
    
    between foo bar
    
    # all check expressions here
    # will be applied to the chunks
    # between /foo/ ... /bar/
    
    hello       # should match 2 times
    
    # if you want to get back to an original search context
    # just say reset_context:
    
    reset_context:
    hello       # should match three times

Range expressions caveats

=over

=item *

range expressions don't keep original order inside range


=back

For example:

    # stdout
    
    foo
        1
        2
        1
        2
    bar
    
    
    # outthentic check
    
    between: foo bar
        regexp: 1
        code: print '#', ( join ' ', map {$_->[0]} @{captures()} ), "\n"
        regexp: 2
        code: print '#', ( join ' ', map {$_->[0]} @{captures()} ), "\n"
    
    # validation output
    
        # 1 1
        # 2 2

=over

=item *

if you need precise order keep preserved use text blocks


=back


=head1 Experimental features

Below is highly experimental features purely tested. You may use it on your own risk! ;)


=head2 Streams

Streams are alternative for captures. Consider following example:

    # stdout
    
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
    
    # outthentic check list
    
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

The code above will print:

    # a 1 0
    # b 2 00
    # c 3 000

Notice something interesting? Output direction has been inverted.

The reason for this is outthentic check expression works in "line by line scanning" mode 
when output gets verified line by line against given check expression. Once all lines are matched
they get dropped into one heap without preserving original "group context". 

What if we would like to print all matching lines grouped by text blocks they belong to which is more convenient?

This is where streams feature comes to rescue.

Streams - are all the data successfully matched for given I<group context>. 

Streams are available for text blocks and range expressions.

Let's rewrite the example:

    begin:
    
        foo
            regexp: \S+
            regexp: \S+
            regexp: \S+
        bar
    
        code:                                   \
            for my $s (@{stream()}) {           \
                print "# ";                     \
                for my $i (@{$s}){              \
                    print $i;                   \
                }                               \
                print "\n";                     \
            }
        
    end:

Stream function returns an arrays of streams. Every stream holds all the matched lines for given block.
So streams preserve group context. Number of streams relates to the number of successfully matched blocks.

Streams data presentation is much closer to what was originally given in stdout:

    # foo a b  c    bar
    # foo 1 2  3    bar
    # foo 0 00 000  bar

Stream could be specially useful when combined with range expressions where sizes
of successfully matched blocks could be different:

    # stdout
    
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
    
    
    # outthentic check
    
    
    between: foo bar
    
    regexp: \d+
    
    code:                                   \
        for my $s (@{stream()}) {           \
            print "# ";                     \
            for my $i (@{$s}){              \
                print $i;                   \
            }                               \
            print "\n";                     \
        }
    
    
    # validation output:
    
    
    # 2 4 6 8
    # 1 3


=head1 Author

L<Aleksei Melezhik|mailto:melezhik@gmail.com>


=head1 Home page

https://github.com/melezhik/outthentic-dsl


=head1 COPYRIGHT

Copyright 2015 Alexey Melezhik.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


=head1 Thanks

=over

=item *

to God as - I<For the LORD giveth wisdom: out of his mouth cometh knowledge and understanding. (Proverbs 2:6)>


=back
