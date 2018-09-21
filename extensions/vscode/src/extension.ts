
import { commands, ExtensionContext, window, workspace } from 'vscode';



import {
	LanguageClient,
} from 'vscode-languageclient';

let client: LanguageClient;

export function activate(context: ExtensionContext) {

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

	constructor(path: string) {
		this.extPath = path;
	}

	public previewScreen () {

		// Get the current text editor
        let editor = window.activeTextEditor;
        if (!editor) {
            return;
		}

		// Get required modules
		const exec = require("child_process").exec;
		const path = require('path');

		// Store current working directory
		let currDir = process.cwd();
		// Change to directory where current file is because cosmos depends on directories
		try {
			process.chdir(path.dirname(editor.document.fileName));
		}
		catch (err) {
		}

		// Build up Ruby Command
		let rubyCmd = 'ruby ' + this.extPath + '/src/screen_preview.rb ' + editor.document.fileName;

		// Execute Ruby Command
		exec(rubyCmd, {env: {'PATH': 'C:\\Ruby24-x64\\bin'}}, function(err, stdout, stderr) { });

		// Change back to directory current working directory
		try {
			process.chdir(currDir);
		}
		catch (err) {
		}
	}

	dispose() {
    }
}