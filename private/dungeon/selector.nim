import math, rbtree, optional_t

type
    Weighted[B] = tuple[total: int, value: B]

    Selector*[B] = object
        ## Given a list of items, each with a weight, this selects a value
        ## from that list
        items: RedBlackTree[Weighted[B], int]

proc newSelector*[B](): Selector[B] =
    ## Creates a new selector
    var rbtree = newRBTree[Weighted[B], int](
        extract = proc (val: Weighted[B]): int = val.total,
        compare = proc (a, b: int): int = cmp(a, b)
    )

    return Selector[B](items: rbtree)

proc add*[B]( selector: var Selector[B], weight: int, value: B ) =
    ## Adds a new value with the given weight
    let highest = max(selector.items)
    let base = if highest.isNone: 0 else: highest.get.total
    selector.items.insert((total: base + weight, value: value))

proc select*[B]( selector: Selector[B], at: int ): Option[B] =
    ## Pulls back the value at the given index, if there is one
    if at < 0:
        return None[B]()
    else:
        let output: Option[Weighted[B]] = selector.items.ceil(at + 1)
        return if output.isSome: Some[B](output.get.value) else: None[B]()

proc random*[B]( selector: Selector[B] ): B =
    ## Returns a random value
    let highest = max(selector.items)
    if highest.isNone:
        raise newException(IndexError, "Selector is empty")
    else:
        return selector.items.ceil(random(highest.get.total) + 1).get.value




