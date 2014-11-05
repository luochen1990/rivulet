require('coffee-mate/global')

Signal = do ->
	gensym = do ->
		cnt = 0
		->
			cnt += 1
			return "rivulet##{cnt}"

	if window?
		class Signal
			constructor: () -> @_symbol = gensym()
			name: -> @_symbol
			trigger: (e) ->
				$(document).triggerHandler @_symbol, [e]
			register: (handler) ->
				f = (_, e) -> handler(e)
				$(document).on @_symbol, f
				(=> $(document).unbind @_symbol, f)
			cancel: ->
				$(document).unbind @_symbol
	else
		events = require('events')
		emitter = new events.EventEmitter
		emitter.setMaxListeners(0) #no limit
		class Signal
			constructor: () -> @_symbol = gensym()
			name: -> @_symbol
			trigger: (e) ->
				emitter.emit @_symbol, e
			register: (f) ->
				emitter.on @_symbol, f
				(=> emitter.removeListener @_symbol, f)
			cancel: ->
				emitter.removeAllListeners @_symbol

	return Signal

class EventStream
	constructor: (@mapf_signal_pairs...) ->
		for [f, sig] in @mapf_signal_pairs
			assert (-> f instanceof Function), "#{f} isnt instanceof Function"
			assert (-> sig instanceof Signal), "#{sig} isnt instanceof Signal"
	signals: ->
		(pair[1] for pair in @mapf_signal_pairs)
	on: (callback) ->
		@mapf_signal_pairs.forEach ([f, sig]) ->
			sig.register (e) -> callback(f(e))

######################### basic event ############################

church_zero = ((x) -> x)

extractE = (elem_selector, event_name) ->
	event_stream = new EventStream([church_zero, new Signal])
	$(elem_selector).on event_name, (e) ->
		setTimeout -> event_stream.mapf_signal_pairs[0][1].trigger e
	event_stream

timerE = (interval) ->
	time = do ->
		t = -1
		(-> ++t)
	event_stream = new EventStream([church_zero, new Signal])
	alarm = ->
		event_stream.mapf_signal_pairs[0][1].trigger time() #the first one with time = 0 was triggered when the ES instance created, and will hardly be captured.
		setTimeout alarm, interval * 1000
	do alarm
	event_stream

##################################################################

EventStream::mapE = (f) ->
	new EventStream (@mapf_signal_pairs.map(([g, sig]) -> [((x) -> f g x), sig]))...

EventStream::streakE = (n) ->
	buf = []
	@mapE (e) ->
		buf.push(e)
		buf.shift(1) if buf.length > n
		return buf[...]

mergeE = (ess...) ->
	[f, sig] = ess[0].mapf_signal_pairs[0]
	new EventStream([].concat((es.mapf_signal_pairs for es in ess)...)...)

class Behavior
	constructor: (@_value, @changeES) ->
	getCurrentValue: -> @_value

behavior = (init_value, change_es = new EventStream) ->
	new Behavior(init_value, change_es)

Behavior::mapB = (f) ->
	new Behavior(f(@_value), @changeES.mapE(f))

##################################################################

plus = (x, y) -> x + y
minus = (x, y) -> x - y

lift = (f) ->
	(bhs...) ->
		values = (bh.getCurrentValue() for bh in bhs)
		bhs.forEach (bh, i) ->
			bh.changeES.on (e) ->
				values[i] = e
		es = new EventStream ([(-> f(values...)), sig] for sig in [].concat((bh.changeES.signals() for bh in bhs)...).sort().unique())...
		new Behavior(f(values...), es)

#timer = timerE(1)
#timer.on (e) ->
#	console.log e

T = behavior(0, timerE(1))
A = lift(plus)(behavior(1), T)
B = lift(minus)(behavior(1), T)

case_1 = ->
	C = lift(plus)(A, B)
	C.changeES.on (e) ->
		log -> e

case_2 = ->
	f = do ->
		last = {x: 1, y: 1}
		(e) ->
			#log -> e
			last[e[0]] = e[1]
			last.x + last.y

	es = mergeE(A.changeES.mapE((x) -> ['x', x]), B.changeES.mapE((y) -> ['y', y]))

	D = behavior(2, es.mapE(f))

	D.changeES.on (e) ->
		log -> e

do case_1
#do case_2

