{CompositeDisposable} = require 'atom'

module.exports = PrismaticParens =
  subscriptions: null
  markerLayers: []
  active: false

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'prismatic-parens:toggle': => @toggle()

    atom.workspace.observeTextEditors (editor) =>
      @colorize(editor)
      editor.onDidChange => # TODO: Don't mark up every change
        @colorize(editor)

  deactivate: ->
    @subscriptions.dispose()
    for layer in @markerLayers
      layer.destroy() unless layer.isDestroyed()

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

    for line, row in lines
      length = buffer.lineLengthForRow(row)
      for column in [0...length]
        # TODO collapse consecutive together for ruby
        scopeDescriptor = editor.scopeDescriptorForBufferPosition([row, column])
        text = editor.getTextInBufferRange([[row, column], [row, column + 1]])
        delimiters.push {
          row: row,
          column: column,
          scopes: scopeDescriptor.scopes,
          text: text
        } if @isDelimiter(scopeDescriptor)

    return delimiters

  isOpenDelimiter: (delimiter) ->
    ['{', '[', '('].includes(delimiter.text)

  isCloseDelimiter: (delimiter) ->
    ['}', ']', ')'].includes(delimiter.text)

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
    colors = ['red', 'orange', 'yellow', 'green', 'blue', 'indigo', 'violet']
    indexInRange = (index - 1) % colors.length
    colors[indexInRange]

  colorize: (editor) ->
    return unless @active
    editor = atom.workspace.getActiveTextEditor() unless editor
    colorIndex = 0
    layer = editor.addMarkerLayer()
    @markerLayers.push(layer)
    lastDelimiter = null
    for delimiter in @delimiters(editor)
      colorIndex++ if @isOpenDelimiter(delimiter)
      marker = layer.markBufferRange(@rangeForDelimiter(delimiter), { invalidate: 'inside' })

      color = if @isInterpolationSigil(delimiter) then @color(colorIndex + 1) else @color(colorIndex)

      decoration = editor.decorateMarker(marker, { type: 'text', style: { color: color } })
      colorIndex-- if @isCloseDelimiter(delimiter)
      lastDelimiter = delimiter

  toggle: ->
    if @active
      console.log('Prismatic Core Failing...')
      @active = false
      for layer in @markerLayers
        layer.destroy() unless layer.isDestroyed()
    else
      console.log('Prismatic Core Online!')
      @active = true
