'use strict';

import {
	IPCMessageReader,
	IPCMessageWriter,
	createConnection,
	IConnection,
	TextDocuments,
	InitializeResult,
	TextDocumentPositionParams,
	CompletionItem,
	Definition,
} from 'vscode-languageserver';

var logger = require('winston');

// Create a connection for the server. The connection uses 
// stdin / stdout for message passing
let connection: IConnection = createConnection(process.stdin, process.stdout);

// Create a simple text document manager. The text document manager
// supports full document sync only
let documents: TextDocuments = new TextDocuments();
// Make the text document manager listen on the connection
// for open, change and close text document events
documents.listen(connection);

// After the server has started the client sends an initilize request. The server receives
// in the passed params the rootPath of the workspace plus the client capabilites. 
let workspaceRoot: string;
connection.onInitialize((params): InitializeResult => {
	workspaceRoot = params.rootPath;
	console.log('COSMOS Server Extension!');
    return {
        capabilities: {
            // Tell the client that the server works in FULL text document sync mode
			textDocumentSync: documents.syncKind,
			completionProvider: {
				resolveProvider: true
			},
			definitionProvider: true,
			executeCommandProvider: {
				commands: [
				]
			}
        }
    }
});

// The content of a text document has changed. This event is emitted
// when the text document first opened or when its content has changed.
documents.onDidChangeContent((change) => {
	//TODO: add symbol parsing here
	console.log('COSMOS document changed!');
	logger.debug(`onDidChangeContent: ${JSON.stringify(change)}`);
});

// Listen on the connection
connection.listen();