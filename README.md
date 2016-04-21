# NAME

Outthentic::DSL

# SYNOPSIS

Language to validate text output.

# Install

    cpanm Outthentic::DSL

# Informal introduction

Alternative outthentic dsl introduction could be found [here](https://github.com/melezhik/outthentic-dsl/blob/master/intro.md)

# Glossary

## Input text

An arbitrary, often unstructured text being verified. It could be any text.

Examples:

* html code
* xml code
* json 
* plain text
* emails :-)
* http headers
* another program languages code

## Outthentic dsl

* Is a language to verify _arbitrary_ plain text

* Outthentic dsl is both imperative and declarative language

### Declarative way

You define rules ( check expressions ) to describe expected content.

### Imperative way

You define a process of verification using custom perl code ( validators, generators, code expressions  ).


## dsl code

A  program code written on outthentic dsl language to verify text input.

## Search context

Verification process is carried out in a given _context_.

But default search context is the same as original input text stream. 

Search context could be however changed in some conditions.

## dsl parser

dsl parser is the program which:

* parses dsl code

* parses text input

* verifies text input ( line by line ) against check expressions ( line by line )


## Verification process

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
    
A final _presentation_ of verification results should be implemented in a certain [client](#clients) _using_ [parser api](#parser-api) and not being defined at this scope. 

For the sake of readability a _fake_ results presentation layout is used in this document. 

## Parser API

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

### new

This is constructor, create Outthentic::DSL instance. 

Obligatory parameters is:

* input text string 

Optional parameters is passed as hashref:

* match_l - truncate matching strings to {match_l} bytes

Default value is \`40'

* debug_mod - enable debug mode

    * Possible values is 0,1,2,3.

    * Set to 1 or 2 or 3 if you want to see some debug information in validation results.

    * Increasing debug_mod value means more low level information appeared.

    * Default value is \`0' - means do not create debug messages.

### validate

Perform verification process. 

Obligatory parameter is:

* a path to file with dsl code

### results  

Returns validation results as arrayref containing { type, status, message } hashrefs.

## Outthentic clients

Client is a external program using dsl API. Existed outthentic clients:

* [swat](https://github.com/melezhik/swat) - web application testing tool

* [outthentic](https://github.com/melezhik/outthentic) - generic testing tool


More clients wanted :) , please [write me](mailto:melezhik@gmail.com) if you have one!

# dsl code syntax

Outthentic dsl code comprises following basic entities:

* Check expressions:

    * plain     strings
    * regular   expressions
    * text      blocks
    * within    expressions
    * range     expressions
    * validator expressions

* Comments

* Blank lines

* Perl expressions

* Generator expressions

# Check expressions

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

* [plain text expressions](#plain-text-expressions) 

* [regular expressions](#regular-expressions).

# Plain text expressions 

Plain text expressions are just a lines should be _included_ at input text stream.

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

    
# Regular expressions

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

 
# One or many?

Parser does not care about _how many times_ a given check expression is matched in input text.

If at least one line in a text match the check expression - _this check_ is considered as succeeded.

Parser  _accumulate_ all matching lines for given check expression, so they could be processed.

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


See ["captures"](#captures) section for full explanation of a captures mechanism:

# Comments, blank lines and text blocks

Comments and blank lines don't impact verification process but one could use them to improve code readability.

## Comments

Comment lines start with \`#' symbol, comments chunks are ignored by parser.


Dsl code:

    # comments could be represented at a distinct line, like here
    The beginning of story
    Hello World # or could be added for the existed expression to the right, like here

## Blank lines

Blank lines are ignored as well.

Dsl code:

    # every story has the beginning
    The beginning of a story
    # then 2 blank lines


    # end has the end
    The end of a story

But you **can't ignore** blank lines in a \`text block' context ( see \`text blocks' subsection ).

Use \`:blank_line' marker to match blank lines.

Dsl code:

    # :blank_line marker matches blank lines
    # this is especially useful
    # when match in text blocks context:

    begin:
        this line followed by 2 blank lines
        :blank_line
        :blank_line
    end:

## Text blocks

Sometimes it is very helpful to match against a \`sequence of lines' like here.


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

\`begin:' \`end:' markers decorate \`text blocks' content. 

Markers should not be followed by any text at the same line.

## Don't forget to close the block ...

Be aware if you leave "dangling" \`begin:' marker without closing \`end': somewhere else 
parser will remain in a \`text block' mode till the end of the file, which is probably not you want:

Dsl code:

        begin:
            here we begin
            and till the very end of test

            we are in `text block` mode

# Perl expressions

Perl expressions are just a pieces of Perl code to _get evaled_ during parsing process. 

This is how it works.

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

One of the use case for Perl expressions is to store [\`captures'](#captures) data.

Dsl code:

    regexp: my name is (\w+) and my age is (\d+)
    code: $main::data{name} = capture()->[0]; $main::data{age} = capture()->[1]; 
    code: print $data->{name}, "\n";
    code: print $data->{age}, "\n";

Input text:

    my name is Alexey and my age is 38

Output:

    Alexey
    38

Additional comments on perl expressions:

* Perl expressions are executed by Perl eval function in context of `package main`, please be aware of that.

* Follow [http://perldoc.perl.org/functions/eval.html](http://perldoc.perl.org/functions/eval.html) to know more about Perl eval function.

# Validators

Validator expressions like Perl expressions are just a piece of Perl code. 

Validators start with \`validator:' marker

A Perl code inside validator block should _return_ array reference. Once code is executed a returned array structure
treated as:

* first element - is a status number ( perl true or false )
* second element - is a helpful message 

Validators a kind of check expressions with check logic _expressed_ in validator code.

Examples.

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
    

Validators are very efficient when gets combined with [\`captures expressions'](#captures)

This is a simple example.

Input text:


    # my family ages list
    alex    38
    julia   32
    jan     2


Dsl code:


    # let's capture name and age chunks
    regexp: /(\w+)\s+(\d+)/

    validator:                          \
    my $total=0;                        \
    for my $c (@{captures()}) {         \
        $total+=$c->[0];                \
    }                                   \
    [ ( $total == 72 ), "total age" ] 


# Generators

Generators is the way to _generate new outthentic entries on the fly_.

Generator expressions like Perl expressions are just a piece of Perl code.

The only requirement for generator code - it should return _reference to array of strings_.

Strings in array returned by generator code _represent_ a _new_ outthentic entities.

A new outthentic entries are passed back to parser and executed immediately.

Generators expressions start with \`:generator' marker.

Here is simple example.

Dsl code:

    # original check list

    Say
    HELLO
 
    # this generator creates 3 new check expressions:

    generator: [ qw{ say hello again } ]


New dsl code:

    # final check list:

    Say
    HELLO
    say
    hello
    again


Here is more complicated example.

Dsl code:


    # this generator generates
    # comment lines
    # and plain string check expressions:

    generator:                                                  \    
    my %d = { 'foo' => 'foo value', 'bar' => 'bar value' };     \
    [ map  { ( "# $_", "$data{$_}" )  } keys %d ]               \


New dsl code:

    # foo
    foo value
    # bar
    bar value


Generators could produce not only check expressions but validators, perl expressions and ... generators.

This is fictional example.

Input Text:

    A
    AA
    AAA
    AAAA
    AAAAA

Dsl code:

    generator:                              \ 
    sub next_number {                       \    
        my $i = shift;                      \ 
        $i++;                               \
        return [] if $i>=5;                 \
        [                                   \
            'regexp: ^'.('A' x $i).'$'      \
            "generator: next_number($i)"    \ 
        ]  
    }

Result - verified


# Multiline expressions

## Multilines in check expressions

When parser parses check expressions it does it in a _single line mode_ :

* a check expression is always single line string

* input text is parsed in line by line mode, thus every line is validated against a single line check expression

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


Use text blocks if you want to _represent_ multiline checks.

## Multilines in perl expressions, validators and generators

Perl expressions, validators and generators could contain multilines expressions

There are two ways to write multiline expressions:

* using `\` delimiters to split multiline string to many chunks

* using HERE documents expressions 


### Back slash delimiters

\`\' delimiters breaks a single line text on a multi lines.

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


### HERE documents expressions 

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

# Captures

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


    validator:                          \
    my $total=0;                        \
    for my $c (@{captures()}) {         \
        $total+=$c->[0];                \
    }                                   \
    [ ($total == 72 ), "total age of my family" ];


## captures() function

captures() function returns an array reference holding all chunks captured during _latest regular expression check_.

Here some more examples.

Dsl code:


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


## capture() function

capture() function returns a _first element_ of captures array. 

it is useful when you need data _related_ only  _first_ successfully matched line.

Dsl code:

    # check if  text contains numbers
    # a first number should be greater then ten

    regexp: (\d+)
    validator: [ ( capture()->[0] >  10 ), " first number is greater than 10 " ];

# Search context modificators

Search context modificators are special check expressions which not only validate text but modify search context.

By default search context is equal to original input text stream. 

That means parser executes validation use all the lines when performing checks 

However there are two search context modificators to change this behavior:
 

* within expressions

* range expressions


## Within expressions

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

Then if checks given by within statement succeed _next_ checks will be executed _in a context of_ succeeded lines:
 
    # but I really need a green one
    green

The code above does follows:

* try to validate input text against regular expression "color: (red|green|blue)"

* if validation is successful new search context is set to all _matching_ lines

These are:

    color: red
    color: green
    color: blue


* thus next plain string checks expression will be executed against new search context

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

Within expressions could be sequential, which effectively means using \`&&' logical operators for within expressions:


    # try to find a date string in following format
    within: date: \d\d\d\d-\d\d-\d\d

    # and try to find year of 2000 in a date string
    within: 2000-\d\d-\d\d

    # and try to find month 04 in a date string
    within: \d\d\d\d-04-\d\d

Speaking in human language chained within expressions acts like _specifications_. 

When you may start with some generic assumptions and then make your requirements more specific. A failure on any step of chain results in
immediate break. 


# Range expressions

Range expressions also act like _search context modificators_ - they change search area to one included
_between_ lines matching right and left regular expression of between statement.


It is very similar to what Perl [range operator](http://perldoc.perl.org/perlop.html#Range-Operators) does 
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


## Multiple range expressions

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


## Restoring search context
        
And finally to restore search context use \`reset\_context:' statement.

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


## Range expressions caveats

### Range expressions can't verify continuous lists.

That means range expression only verifies that there are _some set_ of lines inside some range.
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

# Experimental features

Below is highly experimental features purely tested. You may use it on your own risk! ;)

## Streams

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

Streams - are all the data successfully matched for given _group context_. 

Streams are _applicable_ for text blocks and range expressions.

Let's rewrite last example.

Dsl code:

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


Stream function returns an arrays of _streams_. Every stream holds all the matched lines for given _logical block_.

Streams preserve group context. Number of streams relates to the number of successfully matched groups.

Streams data presentation is much closer to what was originally given in text input:

Output:

    # foo a b  c    bar
    # foo 1 2  3    bar
    # foo 0 00 000  bar


Stream could be specially useful when combined with range expressions of _various_ ranges lengths.

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

    code:                                   \
        for my $s (@{stream()}) {           \
            print "# ";                     \
            for my $i (@{$s}){              \
                print $i;                   \
            }                               \
            print "\n";                     \
        }
    

Output:

    
    # 2 4 6 8
    # 1 3
    # 0 0 0



## Inline code from other languages

WARNING!!! Don't use these features in production unless this message is removed.

One may use various languages in code and generators expressions. Here are examples.

### bash 

    generator:  <<HERE

    !/bin/bash
    echo OK

    HERE

    code: <<HERE
    mkdir -p /tmp/foo   
    HERE

### perl6

    generator: <<PERL6

    !/usr/bin/perl6

    say 'OK';

    PERL6

### ruby

    generator:  <<CODE
    !/usr/bin/ruby

    puts 'OK'

    CODE

    generator:  <<<CODE
    !ruby  \

    puts 'OK'

    CODE


# Author

[Aleksei Melezhik](mailto:melezhik@gmail.com)

# Home page

https://github.com/melezhik/outthentic-dsl

# COPYRIGHT

Copyright 2015 Alexey Melezhik.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

# See also

Alternative outthentic dsl introduction could be found here - [intro.md](https://github.com/melezhik/outthentic-dsl/blob/master/intro.md)

# Thanks

* to God as - *For the LORD giveth wisdom: out of his mouth cometh knowledge and understanding. (Proverbs 2:6)*


