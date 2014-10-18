# rivulet 0.1
# another FRP js library like flapjax

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
	constructor: (@signal = new Signal) ->
	push: (e) -> @signal.trigger e
	do: (foo) -> @signal.register foo
	close: -> do @signal.cancel
	once: (foo) -> @signal.register (=> do foo; do @signal.cancel)

class Behavior
	constructor: (@_value, @_equal = ((a, b) -> a == b and a not instanceof Object and b not instanceof Object)) ->
		@changeE = new EventStream
	value: -> @_value
	update: (es, f = ((e) -> e)) ->
		es.do (e) =>
			new_value = f(e, @_value)
			if not @_equal(new_value, @_value)
				@changeE.push([new_value, @_value])
				@_value = new_value
	apply: (use) ->
		use(@_value)
		@changeE.do ([new_value, old_value]) -> use(new_value)
	watch: (callback) ->
		@changeE.do ([new_value, old_value]) -> callback(new_value, old_value)

################# basic event/behavior source ####################

extractE = (elem_selector, event_name) ->
	event_stream = new EventStream
	$(elem_selector).on event_name, (e) ->
		setTimeout -> event_stream.push e
	event_stream

timerE = (interval) ->
	event_stream = new EventStream
	time = 0 #interval multiply time meas the time passed.
	alarm = ->
		event_stream.push time #the first one with time = 0 was triggered when the ES instance created, and will hardly be captured.
		time += 1
		setTimeout alarm, interval * 1000
	do alarm
	event_stream

extractB = (interval, get_value, equal) ->
	behav = new Behavior(get_value(), equal)
	behav.update timerE(interval), (e) ->
		get_value()
	behav

##################################################################

EventStream::transferE = (transfer) ->
	event_stream = new EventStream
	callback = transfer(event_stream)
	@do (e) ->
		callback(e)
	event_stream

EventStream.mergeE = (es_ls...) ->
	event_stream = new EventStream
	for es in es_ls
		es.do (e) ->
			event_stream.push e
	event_stream

EventStream.zipE = (es_ls...) ->
	es_ls.forEach (es, k) ->
		es_ls[k] = es.mapE((e) -> [k, e])
	EventStream.mergeE(es_ls...).transferE (res) ->
		buffers = dict([k, []] for es, k in es_ls)
		pending_count = es_ls.length
		([k, e]) ->
			buffers[k].push e
			if buffers[k].length == 1
				pending_count -= 1
			if pending_count == 0
				res.push(v[0] for k, v of buffers)
				v.splice(0, 1) for k, v of buffers
				pending_count += 1 for k, v of buffers when v.length == 0

EventStream::mapE = (f) ->
	event_stream = new EventStream
	@do (e) ->
		event_stream.push f(e)
	event_stream

EventStream::filterE = (ok) ->
	event_stream = new EventStream
	@do (e) ->
		event_stream.push e if ok(e)
	event_stream

EventStream::blinkE = (n, k = 1) ->
	event_stream = new EventStream
	cnt = -n + (k < 0)
	unregister = @do (e) =>
		if cnt * k >= 0 and cnt % k == 0
			event_stream.push e
		else
			if k < 0
				do unregister
				do event_stream.close
		cnt += 1
	event_stream

EventStream::onceE = ->
	@blinkE(1, -1)

EventStream::untilE = (end) ->
	event_stream = new EventStream
	unregister = @do (e) =>
		if end(e)
			do unregister
			do event_stream.close
		else
			event_stream.push e
	event_stream

EventStream::delayE = (delay) ->
	event_stream = new EventStream
	@do (e) ->
		setTimeout (-> event_stream.push e), delay * 1000
	event_stream

EventStream::throttleE = (interval) ->
	event_stream = new EventStream
	opened = true
	@do (e) ->
		if opened
			event_stream.push e
			opened = false
			setTimeout (-> opened = true), interval * 1000
	event_stream

##################################################################

mapB = (f, behav_ls..., equal) ->
	if equal instanceof Behavior
		[behav_ls, equal] = [behav_ls.concat equal, null]
	get_value = -> f((behav.value() for behav in behav_ls)...)
	behavior = new Behavior(get_value(), equal)
	for behav in behav_ls
		behavior.update behav.changeE, get_value
	behavior

##################################################################

if not window?
	require('coffee-mate/global')
	do ->
		es1 = timerE(1)
		es2 = timerE(2)
		es = EventStream.zipE(es1, es2)
		es.do (e) ->
			log e

else
	$(document).ready ->
		log 'BEGIN'
		es1 = extractE('#btn_a', 'click').mapE((it) -> it.target)
		es2 = extractE('#btn_b', 'click').mapE((it) -> it.target)
		#es3 = timerE(1)

		#es3_ = es3.transferE (es) ->
		#	cnt = 0
		#	(e) ->
		#		cnt += e
		#		es.push cnt

		#es3_.do (sum) ->
		#	log -> sum

		#EventStream.mergeE(es1, es2, es3).blinkE(5, -1).do (e) ->
		#	log e

		EventStream.mergeE(es1, es2).do (e) ->
			log -> e

		es4 = extractE('#ipt_a', 'keydown')
		es5 = extractE('#ipt_b', 'keydown')
		EventStream.mergeE(es4, es5).do (e) ->
			log -> e

		bh1 = new Behavior('hello')

		bh1.update EventStream.mergeE(es4, es5), (e, v) ->
			float($('#ipt_a').val()) + float($('#ipt_b').val())

		log -> bh1
		log -> bh1.changeE

		log $('#lab_a')
		log $('#lab_a').text
		#bh1.apply $('#lab_a').text
		bh1.apply (v) ->
			log $('#lab_a')
			$('#lab_a').text(v)
		bh1.apply (v) -> $('#ipt_c').val(v)


## UI TESTING FRAMEWORK
#		pack_event = (e) ->
#			[e.target, e.type, dict([k, e[k]] for k in ['target', 'keyCode', 'metaKey', 'altKey', 'ctrlKey', 'shiftKey'])]
#		unpack_event = (obj) ->
#			log -> obj
#			jQuery.Event(obj.second, obj.third)
#
#		class Emulator
#			constructor: (@bh_ls...) ->
#				@records = []
#				log => @bh_ls
#				change_es = (bh.changeE.mapE(([v, old_v]) -> ['B', v]) for bh in @bh_ls)
#				es = EventStream.mergeE(extractE(window, 'keydown click').mapE((e) -> ['E', pack_event(e)]), change_es...)
#				es.do (e) =>
#					log -> e
#					@records.push e
#			get_record: ->
#				json @records
#			play_record: (records_s) ->
#				for r in obj records_s
#					if r.first == 'E'
#						log.info -> unpack_event r.second
#						$(window).trigger(unpack_event r.second)
#					else if r.first == 'B'
#						log.info -> r
#
#		emu = new Emulator(extractB(0.05, (-> $('#ipt_c').val())), extractB(0.05, (-> $('lab_a').val())))
#
#		record = null
#		$('#stopRecord').on 'click', ->
#			record = emu.get_record()
#			log -> 'Records:'
#			log.info -> record
#
#		$('#playRecord').on 'click', ->
#			emu.play_record(record)
#			#window.trigger obj recorder
#
