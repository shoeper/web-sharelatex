SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../../app/js/Features/Editor/EditorHttpController'

describe "EditorHttpController", ->
	beforeEach ->
		@EditorHttpController = SandboxedModule.require modulePath, requires:
			'../Project/ProjectEntityHandler' : @ProjectEntityHandler = {}
			'../Project/ProjectDeleter' : @ProjectDeleter = {}
			"./EditorRealTimeController": @EditorRealTimeController = {}
			"logger-sharelatex": @logger = { log: sinon.stub(), error: sinon.stub() }
			"./EditorController": @EditorController = {}
			'../../infrastructure/Metrics': @Metrics = {inc: sinon.stub()}
			
		@project_id = "mock-project-id"
		@doc_id = "mock-doc-id"
		@user_id = "mock-user-id"
		@parent_folder_id = "mock-folder-id"
		@req = {}
		@res =
			send: sinon.stub()
			json: sinon.stub()
			
	describe "joinProject", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
			@req.query =
				user_id: @user_id
			@projectView = {
				_id: @project_id
			}
			@EditorController.buildJoinProjectView = sinon.stub().callsArgWith(2, null, @projectView, "owner")
			@ProjectDeleter.unmarkAsDeletedByExternalSource = sinon.stub()
			
		describe "successfully", ->
			beforeEach ->
				@EditorHttpController.joinProject @req, @res
				
			it "should get the project view", ->
				@EditorController.buildJoinProjectView
					.calledWith(@project_id, @user_id)
					.should.equal true
					
			it "should return the project and privilege level", ->
				@res.json
					.calledWith({
						project: @projectView
						privilegeLevel: "owner"
					})
					.should.equal true
					
			it "should not try to unmark the project as deleted", ->
				@ProjectDeleter.unmarkAsDeletedByExternalSource 
					.called
					.should.equal false
					
			it "should send an inc metric", ->
				@Metrics.inc
					.calledWith("editor.join-project")
					.should.equal true
					
		describe "when the project is marked as deleted", ->	
			beforeEach ->
				@projectView.deletedByExternalDataSource = true
				@EditorHttpController.joinProject @req, @res
				
			it "should unmark the project as deleted", ->
				@ProjectDeleter.unmarkAsDeletedByExternalSource 
					.calledWith(@project_id)
					.should.equal true

	describe "restoreDoc", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
				doc_id: @doc_id
			@req.body =
				name: @name = "doc-name"
			@ProjectEntityHandler.restoreDoc = sinon.stub().callsArgWith(3, null,
				@doc = { "mock": "doc", _id: @new_doc_id = "new-doc-id" }
				@folder_id = "mock-folder-id"
			)
			@EditorRealTimeController.emitToRoom = sinon.stub()
			@EditorHttpController.restoreDoc @req, @res

		it "should restore the doc", ->
			@ProjectEntityHandler.restoreDoc
				.calledWith(@project_id, @doc_id, @name)
				.should.equal true

		it "should the real-time clients about the new doc", ->
			@EditorRealTimeController.emitToRoom
				.calledWith(@project_id, 'reciveNewDoc', @folder_id, @doc)
				.should.equal true

		it "should return the new doc id", ->
			@res.json
				.calledWith(doc_id: @new_doc_id)
				.should.equal true

	describe "addDoc", ->
		beforeEach ->
			@doc = { "mock": "doc" }
			@req.params =
				Project_id: @project_id
			@req.body =
				name: @name = "doc-name"
				parent_folder_id: @parent_folder_id
			@EditorController.addDoc = sinon.stub().callsArgWith(5, null, @doc)
			@EditorHttpController.addDoc @req, @res

		it "should call EditorController.addDoc", ->
			@EditorController.addDoc
				.calledWith(@project_id, @parent_folder_id, @name, [], "editor")
				.should.equal true

		it "should send the doc back as JSON", ->
			@res.json
				.calledWith(@doc)
				.should.equal true

	describe "addFolder", ->
		beforeEach ->
			@folder = { "mock": "folder" }
			@req.params =
				Project_id: @project_id
			@req.body =
				name: @name = "folder-name"
				parent_folder_id: @parent_folder_id
			@EditorController.addFolder = sinon.stub().callsArgWith(4, null, @folder)
			@EditorHttpController.addFolder @req, @res

		it "should call EditorController.addFolder", ->
			@EditorController.addFolder
				.calledWith(@project_id, @parent_folder_id, @name, "editor")
				.should.equal true

		it "should send the folder back as JSON", ->
			@res.json
				.calledWith(@folder)
				.should.equal true

	describe "renameEntity", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
				entity_id: @entity_id = "entity-id-123"
				entity_type: @entity_type = "entity-type"
			@req.body =
				name: @name = "new-name"
			@EditorController.renameEntity = sinon.stub().callsArg(4)
			@EditorHttpController.renameEntity @req, @res

		it "should call EditorController.renameEntity", ->
			@EditorController.renameEntity
				.calledWith(@project_id, @entity_id, @entity_type, @name)
				.should.equal true

		it "should send back a success response", ->
			@res.send.calledWith(204).should.equal true

	describe "renameEntity with long name", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
				entity_id: @entity_id = "entity-id-123"
				entity_type: @entity_type = "entity-type"
			@req.body =
				name: @name = "EDMUBEEBKBXUUUZERMNSXFFWIBHGSDAWGMRIQWJBXGWSBVWSIKLFPRBYSJEKMFHTRZBHVKJSRGKTBHMJRXPHORFHAKRNPZGGYIOTEDMUBEEBKBXUUUZERMNSXFFWIBHGSDAWGMRIQWJBXGWSBVWSIKLFPRBYSJEKMFHTRZBHVKJSRGKTBHMJRXPHORFHAKRNPZGGYIOT"
			@EditorController.renameEntity = sinon.stub().callsArg(4)
			@EditorHttpController.renameEntity @req, @res

		it "should send back a bad request status code", ->
			@res.send.calledWith(400).should.equal true

	describe "moveEntity", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
				entity_id: @entity_id = "entity-id-123"
				entity_type: @entity_type = "entity-type"
			@req.body =
				folder_id: @folder_id = "folder-id-123"
			@EditorController.moveEntity = sinon.stub().callsArg(4)
			@EditorHttpController.moveEntity @req, @res

		it "should call EditorController.moveEntity", ->
			@EditorController.moveEntity
				.calledWith(@project_id, @entity_id, @folder_id, @entity_type)
				.should.equal true

		it "should send back a success response", ->
			@res.send.calledWith(204).should.equal true

	describe "deleteEntity", ->
		beforeEach ->
			@req.params =
				Project_id: @project_id
				entity_id: @entity_id = "entity-id-123"
				entity_type: @entity_type = "entity-type"
			@EditorController.deleteEntity = sinon.stub().callsArg(4)
			@EditorHttpController.deleteEntity @req, @res

		it "should call EditorController.deleteEntity", ->
			@EditorController.deleteEntity
				.calledWith(@project_id, @entity_id, @entity_type, "editor")
				.should.equal true

		it "should send back a success response", ->
			@res.send.calledWith(204).should.equal true
