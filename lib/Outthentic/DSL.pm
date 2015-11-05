package Outthentic::DSL;

use strict;

require Test::More;

our $VERSION = '0.0.3';

our @CHECK_LIST;

sub check_list {

    shift;

    [ @CHECK_LIST ];
}

sub add_check_item {

    shift;
    my $item = shift;
    push @CHECK_LIST, $item;
        
}



sub new {

    my $class = shift;
    my $output = shift;
    my $opts = shift || {};

    bless {
        output_context => [],
        search_context => [],
        context_populated => 0,
        captures => [],
        within_mode => 0,
        block_mode => 0,
        last_match_line => undef,
        last_check_status => undef,
        debug_mod => 0,
        output => $output,
        match_l => 40,
        %{$opts},
    }, __PACKAGE__;

}

sub populate_context {

    my $self = shift;

    return if $self->{context_populated};

    my $i = 0;

    my @output_context = ();

    for my $l ( split /\n/, $self->{output} ){
        chomp $l;
        $i++;
        $l=":blank_line" unless $l=~/\S/;
        push @output_context, [$l, $i];
    }

    $self->{output_context} = [@output_context];
    $self->{search_context} = [@output_context];

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

    my @output_context         = @{$self->{output_context}};
    my @search_context   = @{$self->{search_context}};
    my @context_new     = ();

    if ($check_type eq 'default'){
        for my $c (@search_context){
            my $ln = $c->[0]; my $next_i = $c->[1];
            if ( index($ln,$pattern) != -1){
                $status = 1;
                $self->{last_match_line} = $ln;
            }
            push @context_new, $output_context[$next_i] if $self->{block_mode};
        }
    }elsif($check_type eq 'regexp'){
        for my $c (@search_context){
            my $re = qr/$pattern/;
            my $ln = $c->[0]; my $next_i = $c->[1];

            my @foo = ($ln =~ /$re/g);

            if (scalar @foo){
                push @captures, [@foo];
                $status = 1;
                push @context_new, $c if $self->{within_mode};
                $self->{last_match_line} = $ln;
            }
            push @context_new, $output_context[$next_i] if $self->{block_mode};

        }
    }else {
        die "unknown check_type: $check_type";
    }


    $self->add_check_item({ status => $status , message => $message });

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
        $self->{search_context} = [@context_new];
    } elsif ( $self->{within_mode} and $status ){
        $self->{search_context} = [@context_new];
    }elsif ( $self->{within_mode} and ! $status ){
        $self->{search_context} = []; # empty context if within expression has not passed 
    }

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
            $self->{search_context} = $self->{output_context};

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
        $self->{search_context} = $self->{output_context};
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
        $self->{search_context} = $self->{output_context}; 
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

    Test::More::diag("handle_plain OK. $l") if $self->{debug_mod} >= 3;
}


sub _short_string {

    my $self = shift;
    my $str = shift;
    my $sstr = substr( $str, 0, $self->{match_l} );

    
    return $sstr < $str ? "$sstr ..." : $sstr; 

}

1;

__END__

=encoding utf8


=head1 SYNOPSIS

Language to validate text output.


=head1 Install

    cpanm Outthentic


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

execution of perl code if entry is perl expression one



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

calculating validation status and generating helping message which could be retrieved later



=item *

a final I<presentation> of validation results (statuses and messages ) should be implimeted in a certain L<client|#clients> I<using> L<parser api|#parser-api> and not being defined at DSL scope. For the sake of readability a table like form ( which is a fake one ) is used for validation results in this document. 



=back


=head2 Parser API

Outthentic provides program api for parser:

    use Test::More qw{no_plan};
    
    use Outthentic::DSL;
    
    my $outh = Outthentic::DSL->new($opts);
    $outh->validate('path/to/check/file','stdout string');
    
    
    for my $chk_item ( @{$outh->check_list}){
        ok($chk_item->{status}, $chk_item->{message})
    }

Method list


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


=back

Set to `1,2,3' if you want to see some debug information in output, default value is `0'.

Increasing debug value means more low level information appeared in console.


=head3 validate

Runs parser for check file and and initiates validation process against stdout.

Obligatory parameter is:

    * path to check file

=over

=item *

check_list



=back

Returns validation results as arrayref containing { status, message } hashrefs.


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

plain strings


=item *

regular expressions


=item *

text blocks


=item *

within expressions


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
    
    
    # validation output
    
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
    Hello World # or could be added to existed expression to the right, like here


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

Perl expressions are just a pieces of perl code to I<get evaled> during parsing process. This is how it works:

    # perl expression between two check expressions
    Once upon a time
    code: print "hello I am Outthentic"
    Lived a boy called Outthentic

Internally once check file gets parsed this piece of DSL code is "turned" into regular perl code:

    execute_check_expression("Once upon a time");
    eval 'print "Lived a boy called Outthentic"';
    execute_check_expression("Lived a boy called Outthentic");

One of the use case for perl expressions is to store L<`captures'|#captures> data:

    regexp: my name is (\w+) and my age is (\d+)
    code: $main::data{name} = capture()->[0]; $main::data{age} = capture()->[1]; 

=over

=item *

Perl expressions are executed by perl eval function in context of C<package main>, please be aware of that.



=item *

Follow L<http://perldoc.perl.org/functions/eval.html|http://perldoc.perl.org/functions/eval.html> to get know more about perl eval.



=back


=head1 Validators

=over

=item *

Validator expressions like perl expressions are just a piece of perl code. 



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
    julia   25
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

Generator expressions like perl expressions are just a piece of perl code.



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
     
     # validation output
    
    +--------+---------------------------------------+
    | status | message                               |
    +--------+---------------------------------------+
    | OK     | matches "Multiline"                   |
    | OK     | matches "string"                      |
    | OK     | matches "here"                        |
    | FAIL   | matches /Multiline \n string \n here/ |
    +--------+---------------------------------------+

Use text blocks if you want to achieve multiline checks.

However when writing perl expressions, validators or generators one could use multilines strings.

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
    julia   25
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


=head1 Within expressions

Within expression acts like regular expression but narrows search context to last matching line:

    # one of 3 colors:
    within: color: (red|green|blue)
    
    # if within expression is successfully passed
    # new search context is last matching line  

In other words when `:within' marker is used parser tries to validate stdout against regular expression following after :within marker and 
if validation is successful new search context is defined:

    # one of 3 colors:
    within: color: (red|green|blue)
    
    # I really need a red color
    red

The code above does follows:

=over

=item *

try to find `color:' followed by `red' or `green' or `blue' word 


=item *

if previous check is successful new context is narrowed to matching line


=item *

thus next plain string checks expression means - try to find `red' in line matching the `color: (red|green|blue)'


=back

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
