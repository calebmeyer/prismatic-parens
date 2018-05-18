{CompositeDisposable} = require 'atom'

module.exports = RainbowDelimiters =
  subscriptions: null
  markerLayers: []
  active: false

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'skittles:toggle': => @toggle()

  deactivate: ->
    @subscriptions.dispose()
    for layer in @markerLayers
      layer.destroy() unless layer.isDestroyed()

  isDelimiter: (scopeDescriptor) ->
    scopeDescriptor.scopes.some (scope) ->
      scope.startsWith('meta.brace') or
      (scope.startsWith('punctuation.definition') and
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
        delimiters.push {
          row: row,
          column: column,
          scopes: scopeDescriptor.scopes,
          text: editor.getTextInBufferRange([[row, column], [row, column + 1]])
        } if @isDelimiter(scopeDescriptor)

    return delimiters

  isOpenDelimiter: (delimiter) ->
    ['{', '[', '('].includes(delimiter.text)

  isCloseDelimiter: (delimiter) ->
    ['}', ']', ')'].includes(delimiter.text)

  rangeForDelimiter: (delimiter) ->
    # TODO: make this support delimiters that aren't just a single character
    [[delimiter.row, delimiter.column], [delimiter.row, delimiter.column + 1]]

  color: (index) ->
    colors = ['red', 'orange', 'yellow', 'green', 'blue', 'indigo', 'violet']
    indexInRange = (index - 1) % colors.length
    colors[indexInRange]

  colorize: (editor) ->
    colorIndex = 0
    layer = editor.addMarkerLayer()
    @markerLayers.push(layer)
    for delimiter in @delimiters(editor)
      colorIndex++ if @isOpenDelimiter(delimiter)
      marker = layer.markBufferRange(@rangeForDelimiter(delimiter), { invalidate: 'inside' })
      decoration = editor.decorateMarker(marker, { type: 'text', style: { color: @color(colorIndex) } })
      colorIndex-- if @isCloseDelimiter(delimiter)

  toggle: ->
    console.log 'Skittles was toggled! Taste the Rainbow!'
    if @active
      @active = false
      for layer in @markerLayers
        layer.destroy() unless layer.isDestroyed()
    else
      @active = true
      atom.workspace.observeTextEditors (editor) =>
        @colorize(editor)
        editor.onDidChange =>
          @colorize(editor)
