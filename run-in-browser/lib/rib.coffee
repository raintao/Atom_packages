shell = require('shell')

module.exports =

  activate: (state) ->
    atom.commands.add 'atom-text-editor',
      'rib:run-in-browser': (event) ->
        editor = atom.workspace.getActivePaneItem()
        file = editor?.buffer.file
        filePath = file?.path
        if filePath?.endsWith('.html') or filePath?.endsWith('.htm')
          shell.openExternal("file://"+filePath)
