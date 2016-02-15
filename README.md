# SYNOPSIS

Language to validate text output.

# Install

    cpanm Outthentic::DSL

# Informal introduction

Alternative introduction into outthentic dsl in more in infromal way could be found here 
- [intro.md](https://github.com/melezhik/outthentic-dsl/blob/master/intro.md)


# Glossary

## Outthentic DSL 

* Is a language to validate _arbitrary_ plain text. Very often a short form \`DSL' is used for this term. 

* Outthentic DSL is both imperative and declarative language.

## Check files

A plain text files containing program code written on DSL to describe text [validation process](#validation-process).

## Code

Content of check file. Should be program code written on DSL.

## Stdout

It's convenient to refer to the text validate by as stdout, thinking that one program generates and yields output into stdout
which is then validated.

## Search context

A synonym for stdout term with emphasis of the fact that validation process if carried out in a given context.

But default search context is equal to original stdout stream. 

Parser verifies all stdout against a list of check expressions. 

But see [search context modificators](#search-context-modificators) section.


## Parser

Parser is the program which:

* parses check file line by line

* creates and then _executes_ outthentic entries represented by parsed lines

* execution of each entry results in one of three things:

    * performing [validation](#validation) process if entry is check expression one

    * generating new outthentic entries if entry is generator one

    * execution of Perl code if entry is Perl expression one



## Validation process

Validation process consists of: 

* checking if stdout matches the check expression or
 
* in case of [validator expression](#validators) :

    * executing validator code and checking if returned value is true 

* generating validation results could be retrieved later

* a final _presentation_ of validation results should be implemented in a certain [client](#clients) _using_ [parser api](#parser-api) and not being defined at DSL scope. For the sake of readability a table like form ( which is a fake one ) is used for validation results in this document. 

## Parser API

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

### new

This is constructor, create Outthentic::DSL instance. 

Obligatory parameters is:

* stdout string 

Optional parameters is passed as hashref:

* match_l - truncate matching strings to {match_l} bytes

Default value is \`40'

* debug_mod - enable debug mode

    * Possible values is 0,1,2,3.

    * Set to 1 or 2 or 3 if you want to see some debug information in validation results.

    * Increasing debug_mod value means more low level information appeared.

    * Default value is \`0' - means do not create debug messages.

### validate

Runs parser for check file and and initiates validation process against stdout.

Obligatory parameter is:

* path to check file

### results  

Returns validation results as arrayref containing { type, status, message } hashrefs.

## Outthentic client

Client is a external program using DSL API. Existed outthentic clients:

* [swat](https://github.com/melezhik/swat)
* [outthentic](https://github.com/melezhik/outthentic)

More clients wanted :) , please [write me](mailto:melezhik@gmail.com) if you have one!

# Outthentic entities

Outthentic DSL comprises following basic entities:

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

Check expressions defines _lines stdout should match_. Here is a simple example:

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


There are two basic types of check expressions - [plain strings](#plain-strings) and [regular expressions](#regular-expressions).

It is convenient to talk about _check list_ as of all check expressions in a given check file.

# Plain string expressions 

        I am ok
        HELLO Outthentic
 

The code above declares that stdout should have lines 'I am ok' and 'HELLO Outthentic'.


# Regular expressions

Similarly to plain strings matching, you may require that stdout has lines matching the regular expressions:

    regexp: \d\d\d\d-\d\d-\d\d # date in format of YYYY-MM-DD
    regexp: Name: \w+ # name
    regexp: App Version Number: \d+\.\d+\.\d+ # version number

Regular expressions should start with \`regexp:' marker.
 

# One or many?

Parser does not care about _how many times_ a given check expression is found in stdout.

It's only required that at least one line in stdout match the check expression ( this is not the case with text blocks, see later )

However it's possible to _accumulate_ all matching lines and save them for further processing:

    regexp: (Hello, my name is (\w+))

See ["captures"](#captures) section for full explanation of a captures mechanism:


# Comments, blank lines and text blocks

Comments and blank lines don't impact validation process but one could use them to improve code readability.

## Comments

Comment lines start with \`#' symbol, comments chunks are ignored by parser:

    # comments could be represented at a distinct line, like here
    The beginning of story
    Hello World # or could be added for the existed expression to the right, like here

## Blank lines

Blank lines are ignored as well:

    # every story has the beginning
    The beginning of a story
    # then 2 blank lines


    # end has the end
    The end of a story

But you **can't ignore** blank lines in a \`text block matching' context ( see \`text blocks' subsection ), use \`:blank_line' marker to match blank lines:

    # :blank_line marker matches blank lines
    # this is especially useful
    # when match in text blocks context:

    begin:
        this line followed by 2 blank lines
        :blank_line
        :blank_line
    end:

## Text blocks

Sometimes it is very helpful to match a stdout against a \`block of strings' goes consequentially, like here:

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

But **will not** for this chunk:

    that string followed by
    this string followed by
    another one string
    with that string
    at the very end.

\`begin:' \`end:' markers decorate \`text blocks' content. \`:being|:end' markers should not be followed by any text at the same line.

Also be aware if you leave "dangling" \`begin:' marker without closing \`end': somewhere else

Parser will remain in a \`text block' mode till the end of check file, which is probably not you want:

        begin:
            here we begin
            and till the very end of test

            we are in `text block` mode

# Perl expressions

Perl expressions are just a pieces of Perl code to _get evaled_ during parsing process. This is how it works:

    # Perl expression between two check expressions
    Once upon a time
    code: print "hello I am Outthentic"
    Lived a boy called Outthentic


Internally once check file gets parsed this piece of DSL code is "turned" into regular Perl code:

    execute_check_expression("Once upon a time");
    eval 'print "Lived a boy called Outthentic"';
    execute_check_expression("Lived a boy called Outthentic");

One of the use case for Perl expressions is to store [\`captures'](#captures) data:

    regexp: my name is (\w+) and my age is (\d+)
    code: $main::data{name} = capture()->[0]; $main::data{age} = capture()->[1]; 

* Perl expressions are executed by Perl eval function in context of `package main`, please be aware of that.

* Follow [http://perldoc.perl.org/functions/eval.html](http://perldoc.perl.org/functions/eval.html) to get know more about Perl eval.

# Validators

* Validator expressions like Perl expressions are just a piece of Perl code. 

* Validator expressions start with \`validator:' marker

* Validator code gets executed and value returned by the code is treated as validation status.

* Validator should return array reference. First element of array is validation status and second one is helpful message which
will be shown when status is appeared in TAP output.

For example:

    # this is always true
    validator: [ 10>1 , 'ten is bigger then one' ]

    # and this is not
    validator: [ 1>10, 'one is bigger then ten'  ]


* Validators become very efficient when gets combined with [\`captures expressions'](#captures)

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


# Generators

* Generators is the way to _generate new outthentic entries on the fly_.

* Generator expressions like Perl expressions are just a piece of Perl code.

* The only requirement for generator code - it should return _reference to array of strings_.

* Strings in array returned by generator code _represent_ new outthentic entities.

* An array items are passed back to parser, so parser generate news outthentic entities and execute them.

* Generators expressions start with \`:generator' marker.

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


# Multiline expressions

When generate and execute check expressions parser operates in a _single line mode_ :

* check expressions are treated as single line strings
* stdout is validated by given check expression in line by line way

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

\`\' delimiters breaks a single line text on a multi lines:


    # What about to validate stdout
    # With sqlite database entries?

    generator:                                                          \

    use DBI;                                                            \
    my $dbh = DBI->connect("dbi:SQLite:dbname=t/data/test.db","","");   \
    my $sth = $dbh->prepare("SELECT name from users");                  \
    $sth->execute();                                                    \
    my $results = $sth->fetchall_arrayref;                              \

    [ map { $_->[0] } @${results} ]


# Captures

Captures are pieces of data get captured when parser validates stdout against a regular expressions:

    # stdout
    # it's my family ages.
    alex    38
    julia   32
    jan     2


    # let's capture name and age chunks
    regexp: /(\w+)\s+(\d+)/


_After_ this regular expression check gets executed captured data will stored into a array:

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



* \`captures()' function is used to access captured data array,

* it returns an array reference holding all chunks captured during _latest regular expression check_.

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

You also may use \`capture()' function to get a _first element_ of captures array:

    # check if stdout contains numbers
    # a first number should be greater then ten

    regexp: (\d+)
    validator: [ ( capture()->[0] >  10 ), " first number is greater than 10 " ];

# Search context modificators

Search context modificators are special check expressions which not only validate stdout but modify search context.

But default search context is equal to original stdout. 

That means outthentic parser execute validation process against original stdout stream

There are two search context modificators to change this behavior:
 

* within expressions

* range expressions


## Within expressions

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

Then if checks given by within statement succeed _next_ checks will be executed _in a context of_
succeeded lines:
 
    # but I really need a green one
    green

The code above does follows:

* try to validate stdout against regular expression "color: (red|green|blue)"

* if validation is successful new search context is set to all _matching_ lines

These are:

    color: red
    color: green
    color: blue


* thus next plain string checks expression will be executed against new search context

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

Within expressions could be sequential, which effectively means using \`&&' logical operators for within expressions:


    # try to find a date string in following format
    within: date: \d\d\d\d-\d\d-\d\d

    # and try to find year of 2000 in a date string
    within: 2000-\d\d-\d\d

    # and try to find month 04 in a date string
    within: \d\d\d\d-04-\d\d

Speaking in human language chained within expressions acts like specifications. When you may start with some
generic assumptions and then make your requirements more specific. A failure on any step of chain results in
immediate break. 


# Range expressions

Between or range expressions also act like _search context modificators_ - they change search area to one included
_between_ lines matching right and left regular expression of between statement.


It is very similar to what Perl [range operator](http://perldoc.perl.org/perlop.html#Range-Operators) does 
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
        
And finally to restore search context use \`reset\_context:' statement:

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

* range expressions don't keep original order inside range

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

* if you need precise order keep preserved use text blocks

# Experimental features

Below is highly experimental features purely tested. You may use it on your own risk! ;)

## Streams

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

Streams - are all the data successfully matched for given _group context_. 

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


# Author

[Aleksei Melezhik](mailto:melezhik@gmail.com)

# Home page

https://github.com/melezhik/outthentic-dsl

# COPYRIGHT

Copyright 2015 Alexey Melezhik.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


# Thanks

* to God as - *For the LORD giveth wisdom: out of his mouth cometh knowledge and understanding. (Proverbs 2:6)*


