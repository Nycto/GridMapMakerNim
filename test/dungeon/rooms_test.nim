import unittest, private/dungeon/rooms

proc `==`(
    placed: PlacedRoom,
    expect: tuple[left, top, width, height: int]
): bool =
    ## Compares a room to a tuple
    placed.room.width == expect.width and
        placed.room.height == expect.height and
        placed.left == expect.left and
        placed.top == expect.top

suite "The room builder should":

    test "Create a single room":
        var selector = newRoomSelector(
            maxSpread = 5,
            padding = 1..5,
            5 -> newRoom(6, 7) )

        let built = selector.build()
        require( built == (left: 0, top: 0, width: 6, height: 7) )

    test "Range of offsets when adding a room":
        var selector = newRoomSelector(maxSpread = 5, padding = 1..5)
        require( selector.getOffsetRange(Side.left) == (min: 0, max: 0) )

        discard selector.add( newRoom(4, 7), Side.left, 0, 0 )

        require( selector.getOffsetRange(Side.left) == (min: -5, max: 12) )
        require( selector.getOffsetRange(Side.right) == (min: -5, max: 12) )
        require( selector.getOffsetRange(Side.top) == (min: -5, max: 9) )
        require( selector.getOffsetRange(Side.bottom) == (min: -5, max: 9) )

    test "Adding a room at a specific offset":
        var selector = newRoomSelector(maxSpread = 5, padding = 1..5)
        discard selector.add( newRoom(4, 7), Side.left, 0, 4 )

        block:
            let added = selector.add( newRoom(4, 4), Side.left, 1, 3 )
            require( added == (left: -7, top: 1, width: 4, height: 4) )

        block:
            let added = selector.add( newRoom(4, 4), Side.top, 0, 5 )
            require( added == (left: 0, top: -9, width: 4, height: 4) )

        block:
            let added = selector.add( newRoom(4, 4), Side.right, 1, 3 )
            require( added == (left: 7, top: 1, width: 4, height: 4) )

        block:
            let added = selector.add( newRoom(4, 4), Side.bottom, 2, 1 )
            require( added == (left: 2, top: 8, width: 4, height: 4) )

    test "Adding rooms that collide with deep nested rooms":
        var selector = newRoomSelector(maxSpread = 5, padding = 1..5)
        discard selector.add( newRoom(6, 2), Side.top, 0, 4 )

        require( selector.add( newRoom(4, 2), Side.top, -3, 0 ).top == -2 )
        require( selector.add( newRoom(4, 2), Side.top, -5, 0 ).top == -4 )
        require( selector.add( newRoom(4, 2), Side.top, -7, 0 ).top == -6 )
        require( selector.add( newRoom(4, 3), Side.top, -9, 0 ).top == -9 )
        require( selector.add( newRoom(4, 3), Side.top, 2, 0 ).top == -3 )

    test "Room collisions should include padding":
        var selector = newRoomSelector(maxSpread = 5, padding = 1..5)
        discard selector.add( newRoom(2, 2), Side.top, 0, 4 )
        require( selector.add( newRoom(2, 2), Side.top, -5, 4 ).top == -6 )

    test "Rooms outside everything else should still collide with something":
        var selector = newRoomSelector(maxSpread = 5, padding = 1..5)
        discard selector.add( newRoom(2, 2), Side.top, 0, 4 )
        require( selector.add( newRoom(2, 2), Side.top, -100, 4 ).top == -6 )



