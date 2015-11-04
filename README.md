# SYNOPSIS

Language to validate text output.

# Glossary

## Outthentic DSL 

Is a language to validate _arbitrary_ plain text. Very often a short form \`DSL' is used for this term. 

Outthentic DSL is both imperative and declarative language.

## Check files

A plain text files containing program code written on DSL to describe text validation process.

## Code

Content of check file. Should be progam code written on DSL.

## Stdout

It's convenient to refer to the text validate by as stdout, thinking that one program generates and yields output into stdout
which is then validated.

## Parser

Parser is the program which:

* parses check file line by line

* creates and then _executes_ outthentic entries represented by parsed lines

* execution of each entry results in one of three things:

    * performing [validation](#validation) process if entry is check expression one

    * generating new outthentic entries if entry is generator one

    * execution of perl code if entry is perl expression one





## Validation process

Validation process consists of: 

* checking if stdout matches the check expression or
 
* in case of [validator expression](#validators) :

    * executing validator code and checking if returned value is true 

* calculating validation status and generating helping message which could be retrieved later

* a certain _presentation_ of validation statuses and messages depend on [client](#clients) _using_ outthentic DSL and
not defined at this scope. In this documentation a simple table form is choosen for the sake of readabilty. 


## DSL API

Outthentic provides program api for parser:

    use Test::More qw{no_plan};

    use Outthentic::DSL;

    my $outh = Outthentic::DSL->new($opts);
    $outh->validate('path/to/check/file','stdout string');


    for my $chk_item ( @{dsl()->check_list}){
        ok($chk_item->{status}, $chk_item->{message})
    }

## Outthentic client

Client is a external program using DSL API. There are two existed otthentic clients:

* [swat](https://github.com/melezhik/swat)
* [outthentic](https://github.com/melezhik/outthentic)


# Outthentic entities

Outhentic DSL comprises following basic entities:

* Check expressions:

    * plain strings
    * regular expressions
    * text blocks
    * within expressions
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


    # validation output

    +--------+------------------------------+
    | status | message                      |
    +--------+------------------------------+
    | OK     | matches "HELLO"              |
    | OK     | matches /\d\d\d\d-\d\d-\d\d/ |
    +--------+------------------------------+


There are two basic types of check expressions - [plain strings](#plain-strings) and [regular expressions](#regular-expressions).

It is convenient to talk about _check list_ as of all check expressions in a given check file.

# Plain String Expressions 

        I am ok
        HELLO Outthentic
 

The code above declares that stdout should have lines 'I am ok' and 'HELLO Outthentic'.


# Regular Expressions

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

* **Comments**

Comment lines start with \`#' symbol, comments chunks are ignored by parser:

    # comments could be represented at a distinct line, like here
    The beginning of story
    Hello World # or could be added to existed expression to the right, like here

* **Blank lines**

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

* **text blocks**

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

Perl expressions are just a pieces of perl code to _get evaled_ during parsing process. This is how it works:

    # perl expression between two check expressions
    Once upon a time
    code: print "hello I am Outthentic"
    Lived a boy called Outthentic


Internally once check file gets parsed this piece of DSL code is "turned" into regular perl code:

    execute_check_expression("Once upon a time");
    eval 'print "Lived a boy called Outthentic"';
    execute_check_expression("Lived a boy called Outthentic");

One of the use case for perl expressions is to store [\`captures'](#captures) data:

    regexp: my name is (\w+) and my age is (\d+)
    code: $main::data{name} = capture()->[0]; $main::data{age} = capture()->[1]; 

* Perl expressions are executed by perl eval function in context of `package main`, please be aware of that.

* Follow [http://perldoc.perl.org/functions/eval.html](http://perldoc.perl.org/functions/eval.html) to get know more about perl eval.

# Validators

* Validator expressions like perl expressions are just a piece of perl code. 

* Validator expressions start with \`validator:' marker

* Validator code gets executed and value returned by the code is treated as validation status.

* Validator should return array reference. First element of array is validation status and second one is helpfull message which
will be shown when status is appeared in TAP output.

For example:

    # this is always true
    validator: [ 10>1 , 'ten is bigger then one' ]

    # and this is not
    validator: [ 1>10, 'one is bigger then ten'  ]


- Validators become very efficient when gets combined with [\`captures expressions'](#captures)

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
    $total == 72


# Generators

* Generators is the way to _generate new outthentic entries on the fly_.

* Generators like perl expressions are just a piece of perl code.

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


# multiline expressions

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
    Multiline \n string \n here
 
 
    # validation output
    OK output matches "Multiline"
    OK output matches "string"
    OK output matches "here"
    NOT_OK output matches "Multiline \n string \n here"


Use text blocks if you want to achieve multiline checks.

However when writing perl expressions, validators or generators one could use multilines strings.

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
    julia   25
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

# Within expressions

Within expression acts like regular expression but narrows search context to last matching line:


    # one of 3 colors:
    within: color: (red|green|blue)

    # if within expression is successfully passed
    # new search context is last matching line  

In other words when \`:within' marker is used parser tries to validate stdout against regular expression following after :within marker and 
if validation is successful new search context is defined:


    # one of 3 colors:
    within: color: (red|green|blue)

    # I really need a red color
    red

The code above does follows:

* try to find \`color:' followed by \`red' or \`green' or \`blue' word 
* if previous check is successful new context is ""narrowed to matching line
* thus next plain string checks expression means - try to find \`red' in line matching the \`color: (red|green|blue)'

Here more examples:

    # try to find a date string in following format
    within: date: (\d\d\d\d)-\d\d-\d\d

    # we only need a dates older then 2000
    validator: [ ( capture->[0] > 2000 ),'date is older then 2000' ];


Within expressions could be sequential, which effectively means using \`&&' logical operators for within expressions:


    # try to find a date string in following format
    within: date: \d\d\d\d-\d\d-\d\d

    # and try to find year of 2000 in a date string
    within: 2000-\d\d-\d\d

    # and try to find month 04 in a date string
    within: \d\d\d\d-04-\d\d

# AUTHOR

[Aleksei Melezhik](mailto:melezhik@gmail.com)

# Home Page

https://github.com/melezhik/outthentic-dsl

# COPYRIGHT

Copyright 2015 Alexey Melezhik.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


# Thanks

* to God as - *For the LORD giveth wisdom: out of his mouth cometh knowledge and understanding. (Proverbs 2:6)*


