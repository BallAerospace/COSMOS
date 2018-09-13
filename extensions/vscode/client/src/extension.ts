import * as path from 'path';
import { workspace, ExtensionContext, window } from 'vscode';

import {
	LanguageClient,
	LanguageClientOptions,
	ServerOptions,
	TransportKind
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