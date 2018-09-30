import * as path from 'path';
import { commands, ExtensionContext, window, workspace } from 'vscode';

import {
	LanguageClient,
	LanguageClientOptions,
	ServerOptions,
	TransportKind
} from 'vscode-languageclient';

let client: LanguageClient;

export function activate(context: ExtensionContext) {

	// The server is implemented in node
	let serverModule = context.asAbsolutePath(
		path.join('server', 'server.js')
	);

	// The debug options for the server
	// --inspect=6009: runs the server in Node's Inspector mode so VS Code can attach to the server for debugging
	let debugOptions = { execArgv: ['--nolazy', '--inspect=6009'] };

	// If the extension is launched in debug mode then the debug server options are used
	// Otherwise the run options are used
	let serverOptions: ServerOptions = {
		run: { module: serverModule, transport: TransportKind.ipc },
		debug: {
			module: serverModule,
			transport: TransportKind.ipc,
			options: debugOptions
		}
	};

	// Options to control the language client
	let clientOptions: LanguageClientOptions = {
		// Register the server for cosmos documents
		documentSelector: ['cosmos' ],
		synchronize: {
			// Notify the server about file changes to '.clientrc files contained in the workspace
			fileEvents: [
				workspace.createFileSystemWatcher('**/config/targets/*/cmdtlm/*.txt', false, false, false),
				workspace.createFileSystemWatcher('**/config/targets/*/cmd_tlm/*.txt', false, false, false),
				workspace.createFileSystemWatcher('**/config/targets/*/screens/*.txt', false, false, false),
				workspace.createFileSystemWatcher('**/config/targets/*/cmd_tlm_server.txt', false, false, false),
				workspace.createFileSystemWatcher('**/config/targets/*/target.txt', false, false, false),
				workspace.createFileSystemWatcher('**/config/targets/tools/*/*.txt', false, false, false),
				workspace.createFileSystemWatcher('**/lib/*.rb', false, false, false),
				workspace.createFileSystemWatcher('**/procedures/*.rb', false, false, false),
			]
		}
	};

	// Create the language client and start the client.
	let disposableLangCl = new LanguageClient('cosmos', 'Language Server Cosmos', serverOptions, clientOptions).start();
	context.subscriptions.push(disposableLangCl);

	// create a telemetry screen viewer
	let screenViewer = new CosmosScreenViewer(context.extensionPath);
	
	// Use Console to log diagnostic info
	console.log('COSMOS Extension!');

	let disposable = commands.registerCommand('cosmos.showGuiPreview', () => {
        screenViewer.previewScreen();
    });

    // Add to a list of disposables which are disposed when this extension is deactivated.
    context.subscriptions.push(screenViewer);
    context.subscriptions.push(disposable);
}

class CosmosScreenViewer {

	extPath: string;

	constructor(extensionPath: string) {
		this.extPath = extensionPath;
	}

	public previewScreen () {

		// Get the current text editor
        let editor = window.activeTextEditor;
        if (!editor) {
            return;
		}

		// Get required modules
		const exec = require("child_process").exec;

		// Store current working directory
		let currDir = process.cwd();
		// Change to directory where current file is because cosmos depends on directories
		try {
			process.chdir(path.dirname(editor.document.fileName));
		}
		catch (err) {
			console.log(err)
		}

		// Build up Ruby Command
		let rubyCmd = 'ruby ' + this.extPath + '/src/screen_preview.rb ' + editor.document.fileName;

		// Execute Ruby Command
		exec(rubyCmd, {env: {'PATH': process.env.path}}, function(err, stdout, stderr) {
			if (stderr != null && stderr != "")
			{
				console.log(stderr)
			}
			if (stdout != null && stdout != "")
			{
				console.log(stdout)
			}
		});

		// Change back to directory current working directory
		try {
			process.chdir(currDir);
		}
		catch (err) {
			console.log(err)
		}
	}

	dispose() {
    }
}