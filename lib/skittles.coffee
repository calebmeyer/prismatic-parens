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

  toggle: ->
    console.log 'Skittles was toggled! Taste the Rainbow!'
    atom.workspace.observeTextEditors (editor) =>
      color = 0
      for row, delimiters of @rowDelimiters(@delimiters(editor))
        $row = $(".line[data-screen-row=#{row}]")
        for delimiter, i in delimiters
          color++ if ['{', '[', '('].includes(delimiter.text)
          $span = $row.find('.syntax--brace, .syntax--bracket')
          $span.eq(i).addClass("rainbow-#{color}")
          color-- if ['}', ']', ')'].includes(delimiter.text)
