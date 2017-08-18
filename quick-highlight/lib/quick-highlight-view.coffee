_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
settings = require './settings'

{
  getVisibleEditors
  matchScope
} = require './utils'

# - Refresh onDidChangeActivePaneItem
# - But dont't refresh invisible editor
# - Update statusbar count on activeEditor was changed
# - Clear marker for invisible editor?: Decide to skip to avoid clere/re-render.
# - Update only keyword added/remove: Achived by diffing.

# https://github.com/atom/text-buffer/pull/192
# Use markerLayer.clear() in future

module.exports =
  class QuickHighlightView
    decorationStyle: null

    constructor: (@editor, {@keywordManager, @statusBarManager, @emitter}) ->
      @keywordToMarkerLayer = Object.create(null)

      @disposables = new CompositeDisposable

      highlightSelection = null
      updateHighlightSelection = (delay) =>
        highlightSelection = _.debounce(@highlightSelection, delay)

      @disposables.add(
        settings.observe('highlightSelectionDelay', updateHighlightSelection)
        settings.observe('decorate', @observeDecorationStyle)
        @editor.onDidDestroy(@destroy)

        # Don't pass function directly since we UPDATE highlightSelection on config change
        @editor.onDidChangeSelectionRange(({selection}) =>
          if selection.isEmpty()
            @clearSelectionHighlight()
          else
            highlightSelection(selection)
         )

        atom.workspace.onDidChangeActivePaneItem(@refresh)
        @keywordManager.onDidChangeKeyword(@refresh)
        @keywordManager.onDidClearKeyword(@clear)
        @editor.onDidStopChanging(@reset)
      )

    observeDecorationStyle: (newValue) =>
      @decorationStyle = newValue
      @reset()

    needSelectionHighlight: (text) ->
      editorElement = @editor.element
      excludeScopes = settings.get('highlightSelectionExcludeScopes')
      switch
        when (not settings.get('highlightSelection'))
            , (excludeScopes.some (scope) -> matchScope(editorElement, scope))
            , /\n/.test(text)
            , text.length < settings.get('highlightSelectionMinimumLength')
            , (not /\S/.test(text))
          false
        else
          true

    highlightSelection: (selection) =>
      @clearSelectionHighlight()
      keyword = selection.getText()
      if @needSelectionHighlight(keyword)
        @markerLayerForSelectionHighlight = @highlight(keyword, 'box-selection')

    clearSelectionHighlight: ->
      @markerLayerForSelectionHighlight?.destroy()
      @markerLayerForSelectionHighlight = null

    highlight: (keyword, color) ->
      markerLayer = @editor.addMarkerLayer()
      @editor.decorateMarkerLayer(markerLayer, type: 'highlight', class: "quick-highlight #{color}")
      @editor.scan ///#{_.escapeRegExp(keyword)}///g, ({range}) ->
        markerLayer.markBufferRange(range, invalidate: 'inside')
      if markerLayer.getMarkerCount() > 0
        markers = markerLayer.getMarkers()
        @emitter.emit('did-change-highlight', {@editor, markers, color})
      markerLayer

    getDiff: ->
      masterKeywords = _.keys(@keywordManager.keywordToColor)
      currentKeywords = _.keys(@keywordToMarkerLayer)
      newKeywords = _.without(masterKeywords, currentKeywords...)
      oldKeywords = _.without(currentKeywords, masterKeywords...)
      if newKeywords.length or oldKeywords.length
        {newKeywords, oldKeywords}
      else
        null

    render: ({newKeywords, oldKeywords}) ->
      # Delete
      for keyword in oldKeywords
        @keywordToMarkerLayer[keyword].destroy()
        delete @keywordToMarkerLayer[keyword]

      # Add
      {keywordToColor} = @keywordManager
      for keyword in newKeywords when color = keywordToColor[keyword]
        @keywordToMarkerLayer[keyword] = @highlight(keyword, "#{@decorationStyle}-#{color}")

    clear: =>
      for keyword, markerLayer of @keywordToMarkerLayer
        markerLayer.destroy()
      @keywordToMarkerLayer = Object.create(null)

    reset: =>
      @clear()
      @refresh()

    refresh: =>
      return unless @editor in getVisibleEditors()

      if diff = @getDiff()
        @render(diff)
      @updateStatusBarIfNecesssary()

    updateStatusBarIfNecesssary: ->
      if settings.get('displayCountOnStatusBar') and @editor is atom.workspace.getActiveTextEditor()
        @statusBarManager.clear()
        keyword = @keywordManager.latestKeyword
        count = @keywordToMarkerLayer[keyword]?.getMarkerCount() ? 0
        if count > 0
          @statusBarManager.update(count)

    destroy: =>
      @clear()
      @clearSelectionHighlight()
      @disposables.dispose()
