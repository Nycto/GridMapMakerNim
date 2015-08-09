import unittest, optional_t, src/selector

suite "The selector should":

    test "Pull `None` when empty":
        var selector = newSelector[string]()
        require( selector.select(10) == None[string]() )

    test "Select values":
        var selector = newSelector[string]()
        selector.add( 5, "First" )
        selector.add( 5, "Second" )
        selector.add( 3, "Third" )
        require( selector.select(-1) == None[string]() )
        require( selector.select(0) == Some[string]("First") )
        require( selector.select(4) == Some[string]("First") )
        require( selector.select(5) == Some[string]("Second") )
        require( selector.select(9) == Some[string]("Second") )
        require( selector.select(10) == Some[string]("Third") )
        require( selector.select(12) == Some[string]("Third") )
        require( selector.select(13) == None[string]() )

    test "Select random value":
        var selector = newSelector[string]()
        selector.add( 5, "First" )
        selector.add( 5, "Second" )
        selector.add( 3, "Third" )
        let select = selector.random
        require( select == "First" or select == "Second" or select == "Third" )

    test "Raise when randomly selecting from an empty selector":
        var selector = newSelector[string]()
        expect(IndexError):
            discard selector.random


