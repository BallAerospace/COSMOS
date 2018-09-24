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
    return {
        capabilities: {
            // Tell the client that the server works in FULL text document sync mode
            textDocumentSync: documents.syncKind
        }
    }
});

// Listen on the connection
connection.listen();