import math, selector, rbtree, optional_t

type
    Room* = tuple[width, height: int]
        ## An individual room

    RoomConfig = object
        ## The config needed for building a room
        weight: int
        builder: proc (): Room

    PlacedRoom* = tuple[left, top: int, room: Room]
        ## A room that has been placed on the grid

    RoomSelector* = object
        ## Selects and constructs individual rooms from a set of RoomBuilders.
        ## `left`, `right`, `top` and `bottom` are the existing rooms sorted
        ## the wall of their bounding box.
        ## `maxSpread` is used when placing a room on the map. It represents
        ## the lateral distance a new room can be from existing rooms.
        ## `padding` is the distance between rooms
        builders: Selector[proc (): Room]
        maxSpread: int
        padding: Slice[int]
        left: RedBlackTree[PlacedRoom, int]
        right: RedBlackTree[PlacedRoom, int]
        top: RedBlackTree[PlacedRoom, int]
        bottom: RedBlackTree[PlacedRoom, int]

    Side* {.pure.} = enum ## \
        ## The side on which a room will be added
        left, right, top, bottom


proc newRoom*( width, height: int ): Room =
    ## Constructs a new room
    return (width, height)


template `->`*( roomWeight: int, build: stmt ): RoomConfig =
    ## Handy shortcut for defining room builders
    RoomConfig(weight: roomWeight, builder: proc(): Room = build)


proc create( self: var RoomSelector, room: Room, left, top: int ): PlacedRoom =
    ## Constructs and indexes a room placed at the given index
    let placed: PlacedRoom = (left, top, room)
    self.left.insert(placed)
    self.right.insert(placed)
    self.top.insert(placed)
    self.bottom.insert(placed)
    return placed

proc width*( room: PlacedRoom ): int {.inline.} = room.room.width
    ## Accessor for reading the width from a placed room

proc height*( room: PlacedRoom ): int {.inline.} = room.room.height
    ## Accessor for reading the height from a placed room

proc bottom*( room: PlacedRoom ): int {.inline.} = room.top + room.room.height
    ## Accessor for reading the bottom edge of a placed room

proc right*( room: PlacedRoom ): int {.inline.} = room.left + room.room.width
    ## Accessor for reading the right edge of a placed room


template createRBTree(
    side: expr,
    reverse: bool = false
): expr {.immediate.} =
    ## Creates a new red/black tree configured for tracking rooms
    newRBTree[PlacedRoom, int](
        proc (room: PlacedRoom): int = room.`side`,
        proc (a, b: int): int =
            return if reverse: -1 * cmp(a, b) else: cmp(a, b)
    )

proc newRoomSelector*(
    maxSpread: int,
    padding: Slice[int],
    builders: varargs[RoomConfig]
): RoomSelector =
    ## Creates a new room selector with the given config
    var selector = newSelector[proc (): Room]()

    for builder in builders:
        selector.add( builder.weight, builder.builder )

    return RoomSelector(
        builders: selector,
        maxSpread: maxSpread,
        padding: padding,
        left: createRBTree(left),
        right: createRBTree(right, true),
        top: createRBTree(top),
        bottom: createRBTree(bottom, true)
    )

proc isEmpty*( self: RoomSelector ): bool {.inline} = self.left.isEmpty()
    ## Returns whether a room selector is empty

proc getOffsetRange*(
    self: RoomSelector, direction: Side
): tuple[min, max: int] =
    ## Returns the minimum and maximum positins for a room being added from
    ## the given direction

    if self.isEmpty():
        return (0, 0)

    template extremes(
        lower: expr, upper: expr, offset: expr, dimension: expr
    ): tuple[min, max: int] =
        ## Pulls the minimum and maximum edges from two of the red black trees. For
        ## example, this is used to grab the leftmost and rightmost walls in a
        ## dungeon
        let farMin = self.`lower`.min().get().`offset` - self.maxSpread
        let farMax = self.`upper`.min().get().`offset` +
            self.`upper`.min().get().`dimension` +
            self.maxSpread
        (farMin, farMax)

    if direction == Side.left or direction == Side.right:
        return extremes(top, bottom, top, height)
    else:
        return extremes(left, right, left, width)


proc isIn( value, low, high: int ): bool = value >= low and value <= high
    ## Returns whether a value is within a given range

proc willCollide(
    room: Room, existing: PlacedRoom,
    offset: int, side: Side, padding: int
): bool {.inline.} =
    ## Returns whether a room will collide with another room if both expanded
    ## out to infinity
    let min = offset - padding
    if side == Side.left or side == Side.right:
        let max = offset + room.height + padding
        return min.isIn( existing.top, existing.bottom ) or
            existing.top.isIn(min, max)
    else:
        let max = offset + room.width + padding
        return min.isIn( existing.left, existing.right ) or
            existing.left.isIn(min, max)

proc add*(
    self: var RoomSelector, room: Room,
    side: Side, offset: int, padding: int
): PlacedRoom =
    ## Adds the given room to the room selector
    if self.isEmpty():
        return self.create(room, left = 0, top = 0)

    template ifCollidesFrom(
        forSide: expr, roomVarName: expr, execute: stmt
    ): stmt {.immediate.} =
        # Executes a statement if a room collides from the given side
        if side == Side.`forSide`:
            for roomVarName in self.`forSide`:
                if room.willCollide(roomVarName, offset, side, padding):
                    execute
            # If it didn't naturall collide with anything, force a collision
            # with the first room on this side
            block:
                let roomVarName: PlacedRoom = self.`forSide`.min.get
                execute

    ifCollidesFrom(left, collidesWith):
        return self.create(room,
            left = collidesWith.left - padding - room.width,
            top = offset)

    ifCollidesFrom(right, collidesWith):
        return self.create(room,
            left = collidesWith.right + padding,
            top = offset)

    ifCollidesFrom(top, collidesWith):
        return self.create(room,
            left = offset,
            top = collidesWith.top - padding - room.height)

    ifCollidesFrom(bottom, collidesWith):
        return self.create(room,
            left = offset,
            top = collidesWith.bottom + padding)

    # This shouldn't be reachable if we limit the spread well enough
    raise newException(Exception, "Room did not collide with any other room!")


proc pickOffset(
    self: RoomSelector,
    roomSize: int,
    extremes: tuple[min, max: int]
): int =
    ## Selects an offset between two extremes for a room of the given size.
    ## Also takes into account the maxSpread for the room selector
    let max = extremes.max - extremes.min - roomSize
    return random(max) + extremes.min - self.maxSpread

proc randomDirection(): Side {.inline.} =
    ## Randomly chooses one of 4 directions
    case random(3)
    of 0: return Side.left
    of 1: return Side.right
    of 2: return Side.top
    of 3: return Side.bottom
    else: raise newException(AssertionError, "Unexpected random number")

proc add*( self: var RoomSelector, room: Room ): PlacedRoom =
    ## Adds the given room

    # If this is the first building, just add it at the origin
    if self.isEmpty():
        return self.create(room, left = 0, top = 0)

    let dir = randomDirection()

    #let wallRange = self.getOffsetRange(dir)

    return self.add(room, dir, 0, self.padding.b)

    #if dir == left or dir == right:
    #    let offset = self.pickOffset(room.width, edges)
    #else:
    #    let offset = self.pickOffset(room.height, edges)


proc build*( self: var RoomSelector ): PlacedRoom =
    ## Builds and places a new room
    return self.add( self.builders.random()() )



