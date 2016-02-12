
# Outthentic DSL - informal introduction


[Outthentic DSL](https://github.com/melezhik/outthentic-dsl) is a language to parse 
and validate unstructured text. 

Two clients are based on this engine to get job done:

* [swat](https://github.com/melezhik/swat) - web application testing tool.

* [outthentic](https://github.com/melezhik/outthentic) - generic purposes testing.

Creating a new outthentic clients - programs using Outthentic DSL API - quite easy 
and everybody welcome to get involved. 

In this short post I am trying to highlight some essential features of the DSL 
helping in automation of type of task related to arbitrary text parsing and validation 
- which are plenty of in our developer's life, huh?

So, lets meet - outthentic DSL ...

# Basic check expressions

Check expressions are search patterns to validate original text input. 

Original text is parsed line by line and every line is matched against check expression.

If at least one line successfuly matches check succeeds, if none of lines does check fails. 

This procedure is repeated for all check expressions in the list.

There are tow type of check expressions: 

* plain text expressions

* regular expressions patterns

Let see a simple example:

     # two checks here     
     Hello # plain text expression 
     regexp: My name is outthentic\W # regular expression

This code verifies will this text input

    Hello
    My name is outthentic!
   
And won't verify this one:

    hello
    My name is outthenticz


Well quite easy so far. Good.

# Greedy expressions

Outthentic check expressions

This is what I mean when I call them greedy. 

Consider this trivial example:


Text input:

    1
    2
    3

DSL code:

    regexp: (\d+)
    code: print "# ", scalar @{captures()}


captures() function returns array of items get captured by latest regular expression check,
we will take a look at this function close a bit latter, but what should be important for us
at the moment is the number of cpatures array equal of successfully matched lines.
 
So the question is What it should be? Not too many variants for answer.

* 1 - nine greedy behavior 
* 3 - greedy behavior

And, yes, it will return 3! As outthentic parser is greedy. It means _ALL_ the 
lines of original input are checked against a given check expressions, and 
thus all successfully matched lines if any hit capture array. It is not really seen at
dsl level as it only tell you whether your check successful or not and does not show you
how many lines of text input succeeded in check, unless you ask him - lets read further ... 



# Text blocks and ranges

Often we need not only verify a single line occurrence but 
_sequences_ of lines or _set_ of  lines inside some text blocks or ranges. 

Text blocks and range expressions abstraction for such a tasks. They could be treated
as _containers_ for basic check expressions - plain text strings or regular expressions.

Let's first consider a text blocks.


## Text blocks. 

Text blocks expressions insists that a sequence of lines should be found at original text input.

Consider this imaginary text output:

    
    <triples>
        1
        2    
        3
    </triples>     

    <triples>
        10
        20    
        30
    </triples>     

    <triples>
        foo
        bar    
        baz
    </triples>     

Now we need to ensure that triples are here. Let's write outthentic dsl code:


    begin:
        <triples>
            regexp \S+
            regexp \S+
            regexp \S+
        </triples>
    end:

Quite self-explanatory so far. Let's add some debugging info here:

    begin:
        <triples>
            regexp (\S+)
            code: print ( join ' ', map { $_->[0] } @{captures()} ), "\n"
            regexp (\S+)
            code: print ( join ' ', map { $_->[0] } @{captures()} ), "\n"
            regexp (\S+)
            code: print ( join ' ', map { $_->[0] } @{captures()} ), "\n"
        </triples>
    end:
  
When run this code we get:

    # 1 10 foo
    # 2 20 bar
    # 3 30 baz

Captures are piece of data get captured for the _latest_ regular expression check,
they are very handy not, only when debugging a code, consider next example:

     begin:
        <triples>
            regexp \d+
            regexp \d+
            regexp \d+
        </triples>
     end:

Now we rewrote a test and require that only triples block having numbers inside will be
taken into account. Ok, let's now count total sum and check if it equal to 65 (as it should be!) 

     begin:
        <triples>
            regexp: (\d+)
            regexp: (\d+)
            regexp: (\d+)
            code: for my $c (@{captures()}) { our $total += $c->[0] }
            validator: [ our $total == 65 , 'total triple's number 65']
        </triples>
     end:

Validator expression evaluate perl expression  and returns it value. DSL parser will treat this
value as check status ( perl true of false ).


Ok, let's add some complexity and group data per blocks. So if have many `<triples> ... </triples>` 
blocks it'd be nice to iterate over blocks data:

     begin:
        <triples>
            regexp: \S+
            regexp: \S+
            regexp: \S+
            code:                                           \
                for my $s (@{stream()}) {                   \
                    print "# ",( join ' ', @{$s} ),"\n";    \
                }                                           \
                print "# next block\n";                     
        </triples>
     end:

Streams are alternative for captures. While capture relates to latest regular expression checks
and get lost with the next expression check, stream instead accumulate all matching lines and
group them per blocks, thus running code above we will have:


    # 1 10 foo
    # next block
    # 2 20 bar
    # next block
    # 3 30 baz

Pretty convenient now, because this is exactly the  groups we  in original text input stream.


## Ranges

Range expressions looks like text blocks, but only for the first glance, they are very effective
but a bit tricky to use for the beginners.

Let's reshape our solution for triples task. Verify that we have triples blocks with numbers inside:


     between: <triples> <\/triples> 
         regexp: \S+

That's it! More laconic than text blocks solution. A few comments here:

* between expression sets new search context for DSL parser, so that instead of looking
through all original input it narrows it search to area _between_ lines matching <triples>
and <\/triples> regular expression. It is very similar to what happen when one use 
[Perl range operator](http://perldoc.perl.org/perlop.html#Range-Operators) when selecting
subsets of lines out of stdin stream:

    while (<STDOUT>){
        if /<triples>/ ... /<\/triples>/
    }


Let's add some debug code to show what happening in more details:


     between: <triples> <\/triples> 
         regexp: (\S+)
         code: print # "", ( join ' ', map { $_->[0] } @{captures()} ), "\n"
    
We see then:

    # 1 10 foo 2 20 bar 3 30 baz

This mean that check expressions inside range block remain "greedy" in comparison with text block,
where they are none greedy.

Check expression inside range block "eat up" all matched lines 

Check expressions inside text block none greedy as line but such a line should be followed by certain other - a sequence
behavior. 

Other differences between text blocks and ranges.

* ranges do not preserve sort order for lines in original input

Consider this code snippet:

    # input data

    foo
        1
        2
        1
        2
    bar 

     between: foo bar 
         regexp: (1)
         code: print "# ", ( join ' ', map { $_->[0] } @{captures()} ), "\n"
         regexp: (2)
         code: print "# ", ( join ' ', map { $_->[0] } @{captures()} ), "\n"
 
A natural assumption that we get something like that:

    # 1 2
    # 1 2

But as check expression inside range blocks are greedy every expression "eat up" all the matching lines, 
so we will get this:

    # 1 1
    # 2 2

Compare with text block solution:

     begin: 
        foo 
            regexp: (\d+)
            code: print "# ", capture()->[0], "\n"
            regexp: (\d+)
            code: print "# ", capture()->[0], "\n"
            regexp: (\d+)
            code: print "# ", capture()->[0], "\n"
            regexp: (\d+)
            code: print "# ", capture()->[0], "\n"
        bar    
     end:

    # 1 
    # 2 
    # 1 
    # 2 

Summary.

So when you want test a sequences ( continuous sets ) you need a text blocks. When you don't
care about ordering and just want to pick up some data included  in a given range you need a range
expressions. 
 
