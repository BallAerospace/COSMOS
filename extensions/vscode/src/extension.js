"use strict";
exports.__esModule = true;
var vscode_1 = require("vscode");
var client;
function activate(context) {
    // Display a message box to the user
    vscode_1.window.showInformationMessage('COSMOS Extension!');
}
exports.activate = activate;
function deactivate() {
    if (!client) {
        return undefined;
    }
    return client.stop();
}
exports.deactivate = deactivate;
