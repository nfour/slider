Promise	= require 'bluebird'
Events	= require './Events'
$		= require 'jquery'

{ merge } = require 'lance/lib/helpers/utils'

###
	v1.2.0
	Slider

	Instantiate with:
		new Slider $('#sliderElement'), optionsObject

	The minimal required markup is:
		<div id="sliderElement">
			<div>Slide1</div>
			<div>Slide2</div>
		</div>

	To work within the slider's children, wrap the slides in [slider-slides]:
		<div id="sliderElement">
			<div slider-slides>
				<div>Slide1</div> <div>Slide2</div>
			</div>
			<div class="someRandomShitYouWantHere"></div>
			<div slide-previous class="yourOwnButton"></div>
		</div>
###
module.exports = class Slider extends Events
	defaultOptions:
		###
			Arrow button functionality

			true: next/previous buttons enabled, markup added if doesn't exist
			false: next/previous buttons disabled, no markup touched
		###
		arrows				: false
		injectCss			: true

		###
			Slider looping

			true	: next/previous can move between the beginning/end
			false	: next/previous become disabled at the end/beginning
		###
		loop				: false

		###
			Transition queuing

			true	: Transitions will queue up and execute one after another.
			false	: Transitions are ignored if currently tranisitioning.
		###
		queued				: true
		
		slideSpeed			: 750
		slideEasing			: 'ease'
		
		autoHeight			: false
		autoHeightSpeed		: 400
		autoHeightEasing	: 'linear'
		
		autoWidth			: false
		autoWidthSpeed		: 400
		autoWidthEasing		: 'linear'
		
		animator			: null # Specify a validAnimator or it will autodetect it for you
		absolute			: false # Positions items absolutely instead of floats
		hideInactive		: false # Improves performance, only works when absolute is true

	validAnimators: [ 'transition', 'velocity', 'animate' ]

	constructor: (@$slider, options) ->
		super
		
		@options = merge {}, @defaultOptions
		merge.white @options, options if options
		
		if not @options.animator
			for animator in @validAnimators when animator of @$slider
				@options.animator = animator
				break

		if @options.animator not in @validAnimators or @options.animator not of @$slider
			throw new Error "Slider - Invalid @options.animator"

		if @options.animator is 'animate' and @options.slideEasing is 'ease'
			@options.slideEasing = 'swing'


		@transitioning	= []
		@slides			= []
		@index			= @$slider.attr('index') or 0
		
		@ready = new Promise (resolve) => @on 'ready', resolve

		@markup()

		@isLoaded.then =>
			@position()
			@emit 'ready', this

		#@$slider.on 'resize', => @position()


	isLoaded: new Promise (resolve) -> $ => $(window).load resolve

	attributes:
		slider		: 'slider'
		next		: 'slider-next'
		previous	: 'slider-previous'
		track		: 'slider-track'
		wrap		: 'slider-slides'
		slide		: 'slider-slide'

	next		: -> @slideTo @index + 1
	previous	: -> @slideTo @index - 1

	setTo: (index) ->
		@transition index, (slide) =>
			@positionTrack slide

			return []

	slideTo: (index) ->
		@transition index, (slide) =>
			awaiting = []
			awaiting.push @animate @$track, { x: - slide.position?.left or 0 }, @options.slideSpeed, @options.slideEasing

			if @options.autoHeight
				awaiting.push @animate @$wrap, { height: slide.height }, @options.autoHeightSpeed, @options.autoHeightEasing

			if @options.autoWidth
				awaiting.push @animate @$wrap, { width: slide.width }, @options.autoWidthSpeed, @options.autoWidthEasing

			return awaiting

	animate: ($el, args...) ->
		new Promise (resolve) =>
			args.push resolve

			options = args[0]
			@axisOptions options

			$el[ @options.animator ] args...

	axisOptions: (options) ->
		switch @options.animator
			when 'velocity'
				options.translateX	or= options.x
				options.translateY	or= options.y
				delete options.x
				delete options.y

			when 'animate'
				options.left	or= options.x
				options.top		or= options.y
				delete options.x
				delete options.y

		return options

	transition: (index = @index, animator) ->
		new Promise (resolve, reject) =>
			previousSlide = @slides[ @index ]

			index = @resolveIndex index

			return resolve() if index is @index or not @slides[ index ]?

			if @transitioning.length
				if not @options.queued
					return resolve()

			@index = index
			slide = @slides[ index ]

			return resolve() if false is @emit [ 'transition', 'transition.start' ], slide

			@transitioning.push index

			slide.$slide.show() if @options.absolute and @options.hideInactive

			if not @options.loop
				if @options.arrows
					@$previous.prop 'disabled', false
					@$next.prop 'disabled', false

					if @index is ( @length - 1 )
						@$next.prop 'disabled', true
					
					if @index is 0
						@$previous.prop 'disabled', true

			Promise.all animator slide
			.finally =>
				@transitioning.pop()

				if previousSlide and @options.absolute and @options.hideInactive
					previousSlide.$slide.hide()

				@emit 'transition.end'

				resolve()

	markup: ->
		if not ( @$wrap = @$slider.find "> [#{@attributes.wrap}]" ).length
			@$slider.wrapInner """<div #{@attributes.wrap} />"""
			@$wrap = @$slider.find "> [#{@attributes.wrap}]" 

		@$wrap.wrapInner "<div #{ @attributes.track } />"
		@$track = @$wrap.find "> [#{ @attributes.track}]"

		@read()

		if @options.arrows
			for key, attribute of { $next: @attributes.next, $previous: @attributes.previous }
				if ( $element = @$slider.find "> [#{attribute}]" ).length
					@[ key ] = $element
				else
					@$slider.append $element = """<button #{attribute} />"""
					@[ key ] = @$slider.find "> [#{attribute}]"

			@$next
				.unbind '.Slider'
				.on 'click.Slider', => @next()
			@$previous
				.unbind '.Slider'
				.on 'click.Slider',	=> @previous()

		return this

	###
		Reads slides from the slides-track element.
		This means you can minipulate the dom then call this
		to instantiate new slides, new ordering, etc.
	###
	read: ->
		@$slides = @$track.children()
		@$slides.attr @attributes.slide, '' # Ensure the attribute is there

		@slides.splice 0, @slides.length
		@$slides.each (index, el) =>
			$slide = $ el

			@slides.push {
				index, $slide
			}

		@length	= @$slides.length

		return this


	position: ->
		@maxWidth	= 0
		@maxHeight	= 0

		for slide in @slides
			@readSlideDimensions slide

			@maxWidth	= slide.width if slide.width > @maxWidth
			@maxHeight	= slide.height if slide.height > @maxHeight

		@slideWidth = @$slider.css('width') or @maxWidth
		#@slideWidth = @maxWidth
		@slideWidth = parseInt @slideWidth.toString().replace /[^\d\-]/g, ''

		@slideHeight = @$slider.css('height') or @maxHeight
		#@slideHeight = @maxHeight
		@slideHeight = parseInt @slideHeight.toString().replace /[^\d\-]/g, ''

		@$track.width @slideWidth * @length
		@$wrap.innerWidth @slideWidth
		@$slides.innerWidth @slideWidth
		#@$wrap.innerHeight @slideHeight


		if @options.absolute
			@absolutelyPosition()
		else
			@readSlidePosition slide for slide in @slides
		
		@positionTrack() if @index of @slides

		if @options.absolute and @options.hideInactive
			for slide in @slides when slide.index isnt @index
				slide.$slide.hide()

		return this

	readSlide: (slide, fn) ->
		if toggleVisibility = @options.absolute and @options.hideInactive and slide.$slide.is( ':hidden' )
			$hidden = ( slide.$slide.add slide.$slide.parents() ).filter ':hidden'
			$hidden.show()

		fn slide

		if toggleVisibility
			$hidden.hide()

	readSlideDimensions: (slide) ->
		@readSlide slide, =>
			slide.height	= slide.$slide.innerHeight()
			slide.width		= slide.$slide.innerWidth()

	readSlidePosition: (slide) ->
		@readSlide slide, =>
			slide.position = slide.$slide.position()

	absolutelyPosition: ->
		for slide in @slides
			position = if slide.index is 0 then 'static' else 'absolute'
			slide.$slide.css {
				position	: position
				float		: 'none'
				left		: @slideWidth * ( slide.index )
				top			: 0
				height		: 'auto'
			}

			@readSlidePosition slide

		return this

	positionTrack: (slide = @slides[ @index ]) ->
		@$track.css @axisOptions { x: - slide.position.left }

		if @options.autoHeight
			@$wrap.css { height: slide.height }
			
		if @options.autoWidth
			@$wrap.css { width: slide.width }
	
	resolveIndex: (index = 0) ->
		if index > ( @length - 1 )
			index = 0
		else if index < 0
			index = @length - 1
		
		return index

	