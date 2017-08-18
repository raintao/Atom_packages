{WorkspaceView} = require 'atom'
Rib = require '../lib/rib'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "Rib", ->
  activationPromise = null

  beforeEach ->
    atom.workspaceView = new WorkspaceView
    activationPromise = atom.packages.activatePackage('rib')

  describe "when the rib:open event is triggered", ->
    it "attaches and then detaches the view", ->
      expect(atom.workspaceView.find('.rib')).not.toExist()

      # This is an activation event, triggering it will cause the package to be
      # activated.
      atom.workspaceView.trigger 'rib:run'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(atom.workspaceView.find('.rib')).toExist()
        atom.workspaceView.trigger 'rib:run'
        expect(atom.workspaceView.find('.rib')).not.toExist()
