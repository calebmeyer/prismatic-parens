{CompositeDisposable} = require 'atom'
{getThemeColors} = require './get-theme-colors'

module.exports = PrismaticParens =
  subscriptions: null
  markerLayers: []
  active: true

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable
    @subscriptionsForTheme = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'prismatic-parens:toggle': => @toggle()

    # should never need these fallbacks, they're just in case
    @colors = ['red', 'orange', 'yellow', 'green', 'blue', 'purple'];

    @debug('Activated')

    @subscriptions.add atom.whenShellEnvironmentLoaded () =>
      @debug('Shell environment loaded')
      @colors = getThemeColors()

      @subscriptions.add atom.themes.onDidChangeActiveThemes () =>
        @debug('themes changed to ' + atom.themes.getActiveThemeNames())
        @colors = getThemeColors()
        @subscriptionsForTheme.dispose() # clear the subscriptions for the previous theme

        @subscriptionsForTheme.add atom.workspace.observeTextEditors (editor) =>
          @colorize(editor)

          @subscriptionsForTheme.add editor.onDidChange => # TODO: Don't mark up every change
            @colorize(editor)

        @subscriptionsForTheme.add atom.workspace.onDidChangeActiveTextEditor (editor) =>
          @colorize(editor) if editor?

  deactivate: ->
    @subscriptions.dispose()
    @markerLayer.destroy() if @markerLayer?

  isDelimiter: (scopeDescriptor) ->
    scopeDescriptor.scopes.some (scope) ->
      scope.startsWith('meta.brace') or
      (scope.startsWith('punctuation.definition') and
        not scope.includes('comment') and
        not scope.includes('string') and
        not scope.includes('constant') and
        not scope.includes('variable')) or
      (scope.startsWith('punctuation.section') and
        not scope.includes('comment') and
        not scope.includes('string'))

  delimiters: (editor) ->
    buffer = editor.getBuffer()
    lines = buffer.getLines()
    delimiters = []
    lastOpenedStack = []

    for line, row in lines
      length = buffer.lineLengthForRow(row)
      for column in [0...length]
        scopeDescriptor = editor.scopeDescriptorForBufferPosition([row, column])
        text = editor.getTextInBufferRange([[row, column], [row, column + 1]])

        if @isDelimiter(scopeDescriptor)
          unmatched = false
          if @isOpenDelimiter(text)
            lastOpenedStack.push({ text: text, index: delimiters.length })
          else if @isCloseDelimiter(text)
            open = lastOpenedStack.pop()

            if open?
              # if the last delimiter matches, skip to the push call below

              # however, if the last delimiter does not match
              if !@matches(open.text, text)
                delimiters[open.index].unmatched = true

                # loop over the remaining delimiters, looking for any that match.
                # Each that doesn't is an unmatched delimiter, mark it and go to the next one.
                # The first that does match terminates the loop and goes to the push call below.
                open = lastOpenedStack.pop()
                while open?
                  if @matches(open.text, text)
                    # found a matching open delimiter
                    break
                  else
                    # found an unmatched open delimiter
                    delimiters[open.index].unmatched = true
                    open = lastOpenedStack.pop()


            else # there was no open delimiter to match to
              unmatched = true

          delimiters.push {
            row: row,
            column: column,
            scopes: scopeDescriptor.scopes,
            text: text,
            unmatched: unmatched
          }

    # @debug(delimiters)

    return delimiters

  isOpenDelimiter: (delimiter) ->
    delimiter in ['{', '[', '(']

  isCloseDelimiter: (delimiter) ->
    delimiter in ['}', ']', ')']

  matches: (open, close) ->
    return true if open is '{' and close is '}'
    return true if open is '[' and close is ']'
    return true if open is '(' and close is ')'
    return false

  isInterpolationSigil: (delimiter) ->
    return false unless delimiter?
    isInterpolation = delimiter.scopes.some (scope) ->
      scope.includes('interpolated') or # ruby
      scope.includes('interpolation') or # python
      scope.includes('template') # javascript
    isSigil = not ['{', '[', '(', ')', ']', '}'].some (nonSigil) -> delimiter.text.includes(nonSigil)
    return isInterpolation and isSigil

  rangeForDelimiter: (delimiter) ->
    # TODO: make this support delimiters that aren't just a single character
    [[delimiter.row, delimiter.column], [delimiter.row, delimiter.column + 1]]

  color: (index) ->
    indexInRange = (index - 1) % @colors.length
    @colors[indexInRange]

  colorize: (editor) ->
    return unless @active
    editor = atom.workspace.getActiveTextEditor() unless editor
    colorIndex = 0

    # regenerate marker layer. This may be bad for performance, but my invalidation was not working.
    @markerLayers[editor.id].destroy() if @markerLayers[editor.id]?
    @markerLayers[editor.id] = editor.addMarkerLayer()

    for delimiter in @delimiters(editor)
      marker = @markerLayers[editor.id].markBufferRange(@rangeForDelimiter(delimiter))
      if delimiter.unmatched
        editor.decorateMarker(marker, { type: 'text', style: { color: 'red', 'border-bottom': '1px dotted red' } })
      else
        colorIndex++ if @isOpenDelimiter(delimiter.text)

        color = if @isInterpolationSigil(delimiter) then @color(colorIndex + 1) else @color(colorIndex)

        decoration = editor.decorateMarker(marker, { type: 'text', style: { color: color } })

        colorIndex-- if @isCloseDelimiter(delimiter.text)

  toggle: ->
    if @active
      console.log('Prismatic Core Failing...')
      @active = false
      if @markerLayers? && @markerLayers.length > 0
        @markerLayers.forEach((layer) => layer.destroy())
        @markerLayers = []
    else
      console.log('Prismatic Core Online!')
      @active = true
      @colorize()

  # utility functions
  debug: (message) ->
    console.log(message) # if atom.inDevMode()
