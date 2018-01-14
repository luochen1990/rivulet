Alias
-----

```
ES = EventStream
VS = VariableSignal
TI = TimeInterval
```

Producer
--------

```
grabSample : IO a -> TI -> VS a

timeout : TI -> ES

risingEdge : VS Bool -> ES ()

fallingEdge : VS Bool -> ES ()

extractAll_from_ : [k] -> EventEmitter k (k -> v) -> ES {tag: k, value: (k -> v)}

extract_from_ : k -> ES {tag: k, value: (k -> v)} -> ES v

extract_from_ : k -> EventEmitter k (k -> v) -> ES v

extract_from_ : k -> WebElemEmitter k (k -> v) -> ES v

```

Convertor
---------

```
mutation : VS a -> ES {old: a, new: a}

accumulate : (a -> r -> r) -> r -> ES a -> VS r

lift : (a -> b -> c) -> (VS a -> VS b -> VS c)
```

Calculator
----------

```
map : (a -> b) -> ES a -> ES b

filter : (a -> Bool) -> ES a -> ES a

cooled : TI -> ES a -> VS Bool

cooldown: TI -> ES a -> ES ()
cooldown t = risingEdge cooled(t)

groupBy : ES k -> ES a -> ES (k, [a])

streak : Nat -> ES a -> ES [a]

takeUntil : ES _ -> ES a -> ES a

dropUntil : ES _ -> ES a -> ES a

merge : (t : (k -> Type)) -> (DMap k (\i => (ES (t i)))) -> ES {tag: k, value: (\i => t i)}   //dependent tuple needed to support different type of v

fusion : [ES a] -> ES [a]

zip : [ES a] -> ES [a]

delay : TI -> ES a -> ES a

throttle : TI -> ES a -> ES a
```

Consumer
--------

```
glimpse : VS a -> IO a

subscribe : ES a -> (a -> IO b) -> IO ()

then : ES a -> (Maybe a -> Promise b) -> Promise b
```

