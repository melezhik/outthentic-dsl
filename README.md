# SYNOPSIS

Outthentic DSL

# Outthentic DSL

* DSL provides some meta language to validate _arbitrary_ plain text. 

* One should create a so called \`check files' - DSL scripts to describe validation process. 

* Outthentic DSL is both imperative and declarative language.

* It's convenient to refer to the text validate by as \`stdout', thinking about a program generating and yielding
an output to the STDOUT which then gets validated by.


# Check files

Check file is a regular file in text plain format. The content of check file is a DSL script. 

# Parser

\`Parser' is the program which:

* parses processes check file line by line
* creates and then _executes_ outthentic entry represented by parsed line(s)
* execution of entry results in one of three :
    * validation stdout against check expression - if entry is check expression
    * generating new outhentic entries - if entry is generator entry
    * execution of perl code - if entry is perl expression

# Outthentic entries

Outhentic DSL comprises following basic entities, listed at pretty arbitrary order:

* check expressions: 
    * plain strings 
    * regular expressions
    * text blocks
    * within expressions
* comments
* blank lines
* perl expressions
* generators

# Check expressions

* Check expressions defines _what lines stdout should have_

    # stdout
    HELLO
    HELLO WORLD
    My birth day is: 1977-04-16


    # check list
    HELLO
    regexp: \d\d\d\d-\d\d-\d\d


    # check output
    HELLO matches
    regexp: \d\d\d\d-\d\d-\d\d matches



* There are two type of check expressions - plain strings and regular expressions.

* It is convenient to talk about _check list_ as of all check expressions in a given check file.

## plain string

        I am ok
        HELLO Outthentic
 

The code above declares that stdout should have lines 'I am ok' and 'HELLO Outthentic'.


## regular expression

Similarly to plain strings matching, you may require that stdout has lines matching the regular expressions:

    regexp: \d\d\d\d-\d\d-\d\d # date in format of YYYY-MM-DD
    regexp: Name: \w+ # name
    regexp: App Version Number: \d+\.\d+\.\d+ # version number

Regular expressions should start with \`regexp:' marker.
 

## captures

Parser does not care about _how many times_ a given check expression is found in stdout.

It's only required that at least one line in stdout match the check expression ( this is not the case with text blocks, see later )

However it's possible to _accumulate_ all matching lines and save them for further processing:

    regexp: (Hello, my name is (\w+))

See ["captures"](#captures) section for full explanation of a captures mechanism:


# Comments, blank lines and text blocks

Comments and blank lines don't impact validation process but one could use them to improve code readability.


* **comments**

Comment lines start with \`#' symbol, comments chunks are ignored by parser:

    # comments could be represented at a distinct line, like here
    The beginning of story
    Hello World # or could be added to existed expression to the right, like here

* **blank lines**

Blank lines are ignored as well:

    # every story has a begining 
    The beginning of story
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

Perl expressions are just a pieces of perl code to _get evaled_ during pasing process. This is how it works:

    # perl expression between two check expressions
    Once upon a time
    code: print "hello I am Outthentic"
    Lived a boy called Outthentic


Internaly once check file gets parsed this piece of DSL code is "turned" into regular perl code:

    ok($status,"stdout matches Once upon a time");
    eval 'print "Lived a boy called Outthentic"';
    ok($status,"stdout matches Lived a boy called Outthentic");

So, all perl expressions in DSL code will be replaced by perl eval {code} expressions.

Example with 'print "Lived a boy called Outthentic"' is quite useless, here some more realistic examples:


    # use of Test::More functions 
    # to modify validation workflow:

    # skip tests

    code: skip('next 3 checks are skipped',3) # skip three next checks forever
    color: red
    color: blue
    color: green

    number:one
    number:two
    number:three

    # skip tests conditionally

    color: red
    color: blue
    color: green

    code: skip('numbers checks are skipped',3)  if $ENV{'skip_numbers'} # skip three next checks if skip_numbers set

    number:one
    number:two
    number:three


Perl expressions could be effectively used with [\`captures'](#captures):

    regexp: my name is (\w+) and my age is (\d+)
    code: cmp_ok(capture()->[1],'>',20,capture()->[0].' is adult one'); 

* Perl expressions are executed by perl eval function in context of `package main`, please be aware of that.

* Follow [http://perldoc.perl.org/functions/eval.html](http://perldoc.perl.org/functions/eval.html) to get know more about perl eval.

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

When generate and execute check expessions parser operates in a _single line mode_ :

* check expressions are treated as single line strings 
* stdout is validated by given check expression in line by line way:

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

However when writing perl expressions or generators one could use multilines strings. 

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


    code:                               \
    my $total=0;                        \
    for my $c (@{captures()}) {         \
        $total+=$c->[0];                \
    }                                   \
    cmp_ok( $total,'==',72,"total age of my family" );



- \`captures()' function is used to access captured data array, 

- it returns an array reference holding all chunks captured during _latest regular expression check_.


Here some more examples:

    # check if stdout contains numbers,
    # then calculate total amount
    # and check if it is greater then 10

    regexp: (\d+)
    code:                               \
    my $total=0;                        \
    for my $c (@{captures()}) {         \
        $total+=$c->[0];                \
    }                                   \
    cmp_ok( $total,'>',10,"total amount is greater than 10" );


    # check if stdout contains lines
    # with date formatted as date: YYYY-MM-DD
    # and then check if first date found is yesterday

    regexp: date: (\d\d\d\d)-(\d\d)-(\d\d)
    code:                               \
    use DateTime;                       \
    my $c = captures()->[0];            \
    my $dt = DateTime->new( year => $c->[0], month => $c->[1], day => $c->[2]  ); \
    my $yesterday = DateTime->now->subtract( days =>  1 );                        \
    cmp_ok( DateTime->compare($dt, $yesterday),'==',0,"first day found is - $dt and this is a yesterday" );

You also may use \`capture()' function to get a _first element_ of captures array:

    # check if stdout contains numbers
    # a first number should be greater then ten

    regexp: (\d+)
    code: cmp_ok( capture()->[0],'>',10,"first number is greater than 10" );


# AUTHOR

[Aleksei Melezhik](mailto:melezhik@gmail.com)

# Home Page

https://github.com/melezhik/outthentic-dsl

# COPYRIGHT

Copyright 2015 Alexey Melezhik.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


# Thanks

* to God as - *For the LORD giveth wisdom: out of his mouth cometh knowledge and understanding. (Proverbs 2:6)*


