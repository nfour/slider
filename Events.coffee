# v1.5.0

{ typeOf } = require 'lance/lib/helpers/utils'

###
	Event emitter. Backwards compatible with node.js EventEmitter API.

	All functions return `this` unless otherwise specified, allowing chaining.

###
module.exports = class Events
	constructor: ->
		@_events		= {}
		@_maxListeners	= @defaultMaxListeners

	@::defaultMaxListeners	=
	@::_maxListeners		= 20

	###
		Relays events from another emitter to this one

		@param emitter {EventEmitter} An EventEmitter to listen on
		@param events {Array or Object}
			Object: { event: eventAs }
			Array: [ event ]

	###
	relayListeners: (emitter, events) ->
		if typeOf.Object events
			@relayListener emitter, event, eventAs for event, eventAs of events
		else
			events = Object.keys emitter._events if not events
			@relayListener emitter, event for event in events

		return this

	###
		Relays an event from another emitter to this

		@param emitter {EventEmitter} An EventEmitter to listen on
		@param event {String} An event to listen for on `emitter`
		@param eventAs {String} The event to emit, defaults to the `event`

	###
	relayListener: (emitter, event, eventAs) ->
		emitter.on event, (args...) =>
			args.unshift eventAs or event
			@emit args...

		return this

	###
		Emits an event

		@param listeners {Array, String}
			An array of listener event names to emit the event to

			Example: events.emit [ 'open', 'close' ], -> # executed on both open and close

		@param args... {Mixed}
			Arguments to bind to the event emission

			Example: events.emit 'eventName', arg1, arg2, arg3, arg4
	###
	emit: (listeners, args...) ->
		listeners = [ listeners ] if typeof listeners is 'string'

		for key in listeners
			if '*' of @_events
				wildArgs = args.slice()
				wildArgs.unshift key

				for event in @_events['*']
					event.callback.apply null, wildArgs

			if key of @_events
				for event, index in @_events[ key ] by -1
					result = event.callback.apply null, args
					++event.count

					if event.limit <= event.count
						@_events[ key ].splice index, 1

					if result is false # stops event propogation
						break

		return this


	###
		Listens for an event. By default, listening with defaults is disabled

		@param listeners {Array, String}
			[ 'event1', 'event2' ] or 'event1'
			Event names to listen for

		@param o {Object} Optional options object to change listener behavior
			@prop duplicates: false {Boolean}
				This causes the `callback` to be searched for and if matched, a new
				listener is NOT added, preventing duplicate emitters

			@prop limit: Infinity {Number}
				This allows for `many` or `once` behaviour. Each time an event is fired
				the `event.count` is incremented. When it equals the `limit` the event is discarded.

				Example:
					`.on 'test', { limit: 1 }, ->`
					The above is equal to `.once 'test', ->`

		@param callback {Function} Called on each succussful emission pass
	###
	on: (listeners, o, callback) ->
		listeners = [ listeners ] if typeof listeners is 'string'

		if not callback
			callback = o or ->
			o = { duplicates: false }

		for key in listeners
			event = {
				callback
				count: 0
				limit: o.limit or Infinity
			}

			if key not of @_events
				events = @_events[ key ] = []
			else
				events = @_events[ key ]

				if events.length > @_maxListeners
					console.log this, "Events.maxListeners of `#{ @_maxListeners } exceeded to `#{ events.length }` for event `#{ key }`"

				if not o.duplicates
					found = false
					for e in events when callback is e.callback
						found = true
						break

					continue if found
				
			events.unshift event

		return this

	###
		Unlistens to an event

		@param listeners {Array, String}
			[ 'event1', 'event2' ] or 'event1'
			Event names to remove the event from

		@param callback {Function} Callback which will be compared to find the correct event
	###
	off: (listeners, callback) ->
		if typeof listeners is 'string'
			listeners = [ listeners ]

		for key in listeners when events = @_events[key]
			for event, index in events by -1 when event.callback is callback
				events.splice index, 1

		return this

	###
		Removes all listeners either for a specific event or all events

		@param event {String}
	###
	removeAllListeners: (event) ->
		if not event?
			delete @_events[ key ] for key of @_events
		else
			if @_events[ event ]
				delete @_events[ event ]

		return this

	setMaxListeners: (@_maxListeners) ->

	###
		Listens once to an event, then discards the listener
	###
	once: (listeners, callback) ->
		@on listeners, { limit: 1 }, callback

	listeners: (event) -> return @_events[ event ] or null

	
	@::addListener		= @::on
	@::removeListener	= @::off
	@::relayEvents		= @::relayListeners
	@::relayEvent		= @::relayListener
	@::one				= @::once


