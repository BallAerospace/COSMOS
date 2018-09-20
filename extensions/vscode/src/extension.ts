
import { ExtensionContext, window } from 'vscode';

import {
	LanguageClient,
} from 'vscode-languageclient';

let client: LanguageClient;

export function activate(context: ExtensionContext) {

	// Display a message box to the user
	window.showInformationMessage('COSMOS Extension!');
}

export function deactivate(): Thenable<void> {
	if (!client) {
		return undefined;
	}
	return client.stop();
}