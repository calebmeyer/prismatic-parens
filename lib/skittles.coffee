{CompositeDisposable} = require 'atom'
_ = require 'lodash'
$ = require 'jquery'

module.exports = RainbowDelimiters =
  subscriptions: null

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'skittles:toggle': => @toggle()

  deactivate: ->
    @subscriptions.dispose()

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

  rowDelimiters: (delimiters) ->
    _.groupBy(delimiters, 'row')

  colorize: (editor) ->
    color = 0
    layer = editor.addMarkerLayer()
    for delimiter in @delimiters(editor)
      color++ if ['{', '[', '('].includes(delimiter.text)
      marker = layer.markBufferRange([[delimiter.row, delimiter.column], [delimiter.row, delimiter.column + 1]])
      decoration = editor.decorateMarker(marker, { type: 'text', class: 'content-open-brace rainbow-' + color})
      console.log(decoration)
      color-- if ['}', ']', ')'].includes(delimiter.text)

  toggle: ->
    console.log 'Skittles was toggled! Taste the Rainbow!'
    atom.workspace.observeTextEditors (editor) =>
      @colorize(editor)
