import { Component, OnInit, OnDestroy } from '@angular/core';
import { CosmosApiService, GetCmdParamListItem } from '../../services/cosmos-api.service';
import { CmdParamValAndStates, CmdParam } from './command-parameter-editor.component';
import { Observable } from "rxjs/Observable";

@Component({
  selector: 'cosmos-command-sender',
  templateUrl: './command-sender.component.html',
  styleUrls: ['./command-sender.component.css']
})
export class CommandSenderComponent implements OnInit {

  targetName:string = '';
  commandName:string = '';
  ignoreRangeChecks:boolean = false;
  ignoreRangeChecksIcon = 'fa-circle-o';
  showIgnoredParams:boolean = false;
  showIgnoredParamsIcon = 'fa-circle-o';
  ignoredParams:string[] = [];
  rows:CmdParam[] = [];
  interfaces = [];
  selectedInterface = '';
  rawCmdFile = null;
  menuItems = [];
  status:string = '';
  displaySendHazardous:boolean = false;
  displayErrorDialog:boolean = false;
  displaySendRaw:boolean = false;
  sendDisabled:boolean = true;

  constructor(private api: CosmosApiService) { }

  buildMenu() {
    var fileMenuItems = {
      label: 'File', items:
        [
          {label: 'Send Raw',
           command: () => {this.setupRawCmd()} }
        ]
    };

    var modeMenuItems = {
      label: 'Mode', items:
      [
        {label: 'Ignore Range Checks',
         icon: this.ignoreRangeChecksIcon,
         command: () => {this.toggleIgnoreRangeChecks()} },
        {label: 'Show Ignored Parameters',
         icon: this.showIgnoredParamsIcon,
         command: () => {this.toggleShowIgnoredParams()} },
      ]
    };
    this.menuItems = [fileMenuItems, modeMenuItems];
  }

  toggleIgnoreRangeChecks() {
    if (this.ignoreRangeChecks == false) {
      this.ignoreRangeChecks = true;
      this.ignoreRangeChecksIcon = 'fa-check-circle-o';
      this.buildMenu();
    }
    else {
      this.ignoreRangeChecks = false;
      this.ignoreRangeChecksIcon = 'fa-circle-o';
      this.buildMenu();
    }
  }

  toggleShowIgnoredParams() {
    if (this.showIgnoredParams == false) {
      this.showIgnoredParams = true;
      this.showIgnoredParamsIcon = 'fa-check-circle-o';
      this.buildMenu();
    }
    else {
      this.showIgnoredParams = false;
      this.showIgnoredParamsIcon = 'fa-circle-o';
      this.buildMenu();
    }
    this.updateCmdParams();
  }

  ngOnInit() {
    this.buildMenu();    
  }

  isFloat(str) {
    // Regex to identify a string as a floating point number
    if (/^\s*[-+]?\d*\.\d+\s*$/.test(str)) {
      return true;
    }
    // Regex to identify a string as a floating point number in scientific notation. 
    if (/^\s*[-+]?(\d+((\.\d+)?)|(\.\d+))[eE][-+]?\d+\s*$/.test(str)) {
      return true;
    }
    return false;
  }

  isInt(str) {
    // Regular expression to identify a String as an integer
    if (/^\s*[-+]?\d+\s*$/.test(str)) {
      return true;
    }

    // # Regular expression to identify a String as an integer in hexadecimal format
    if (/^\s*0[xX][\dabcdefABCDEF]+\s*$/.test(str)) {
      return true;
    }
    return false;
  }

  isArray(str) {
    // Regular expression to identify a String as an Array
    if (/^\s*\[.*\]\s*$/.test(str)) {
      return true;
    }
    return false;
  }

  removeQuotes(str) {
    // Return the string with leading and trailing quotes removed
    if (str.length < 2) {
      return str;
    }
    var firstChar = str.charAt(0);
    if ((firstChar != '"') && (firstChar != "'")) {
      return str;
    }
    var lastChar = str.charAt(str.length-1);
    if (firstChar != lastChar) {
      return str;
    }
    return str.slice(1, -1);
  }

  convertToValue(param:CmdParam) {
    if (typeof param.val_and_states.val != 'string')
    {
      return param.val_and_states.val;
    }

    var str = param.val_and_states.val;
    var quotes_removed = this.removeQuotes(str);
    if (str == quotes_removed) {
      var upcaseStr = str.toUpperCase();
    
      if (((param.type == "STRING") || (param.type == "BLOCK")) && upcaseStr.startsWith("0X")) {
        var hexStr = upcaseStr.slice(2);
        if ((hexStr.length % 2) != 0) {
          hexStr = "0" + hexStr;
        }
        var jstr = {"json_class":"String", "raw":[]}
        for (var i = 0; i < hexStr.length; i += 2) {
          var nibble = hexStr.charAt(i) + hexStr.charAt(i+1);
          jstr.raw.push(parseInt(nibble, 16));
        }
        return jstr;
      }
      else {
        if (upcaseStr == 'INFINITY') {
          return Infinity;
        }
        else if (upcaseStr == '-INFINITY') {
          return -Infinity;
        }
        else if (upcaseStr == 'NAN') {
          return NaN;
        }
        else if (this.isFloat(str)) {
          return parseFloat(str);
        }
        else if (this.isInt(str)) {
          return parseInt(str);
        }
        else if (this.isArray(str)) {
          return eval(str)
        }
        else {
          return str;
        }
      }
    }
    else {
      return quotes_removed;
    }
  }

  convertToString(value) {
    var return_value = ''
    if (Object.prototype.toString.call(value).slice(8, -1) === 'Array') {
      var arrayLength = value.length;
      return_value = '[ ';
      for (var i = 0; i < arrayLength; i++) {
        if (Object.prototype.toString.call(value[i]).slice(8, -1) === 'String') {
          return_value += '"' + value[i] + '"';
        } else {
          return_value += value[i];
        }
        if (i != (arrayLength - 1)) {
          return_value += ', ';
        }
      }
      return_value += ' ]'
    }
    else if (Object.prototype.toString.call(value).slice(8, -1) === 'Object') {
      if (value.json_class == "String" && value.raw) {
        // This is binary data, display in hex.
        return_value = '0x'
        for (var i = 0; i < value.raw.length; i++) {
          var nibble = value.raw[i].toString(16).toUpperCase();
          if (nibble.length < 2) {
            nibble = "0" + nibble;
          }
          return_value += nibble;
        }
      }
      else if (value.json_class == "Float" && value.raw) {
        return_value = value.raw;
      }
      else {
        // TBD - are there other objects that we need to handle?
        return_value = String(value);
      }
    }
    else {
      return_value = String(value);
    }
    return return_value;
  }

  commandChanged(event) {
    this.targetName = event.targetName;
    this.commandName = event.commandName;
    this.updateCmdParams();
  }

  updateCmdParams() {
    this.sendDisabled = true;
    this.ignoredParams = []
    this.rows = []
    this.status = "Attempting to get ignored parameters from server...";
    this.api.get_target_ignored_parameters(this.targetName).retry().subscribe(
    (ignoredParams) => {
      this.ignoredParams = ignoredParams;
      this.status = "Attempting to get command parameters from server...";
      this.api.get_cmd_param_list(this.targetName, this.commandName).retry().subscribe(
      (data:GetCmdParamListItem[]) => {
        for (var i = 0; i < data.length; i++)
        {
          if (!this.ignoredParams.includes(data[i][0]) || this.showIgnoredParams) {
            this.rows.push({
              parameter_name : data[i][0],
              val_and_states : {val: this.convertToString(data[i][1]), states: data[i][2], selected_state: null, selected_state_label: '', manual_value: null},
              description    : data[i][3],
              units          : data[i][5],
              type           : data[i][7],
            });
          }
        }
        this.sendDisabled = false;
        this.status = '';
      },
      (error) => {
        this.displayError('getting command parameters', error);
      });
    },
    (error) => {
      this.displayError('getting ignored parameters', error);
    });
  }

  statusChange(event) {
    this.status = event.status;
  }
  
  sendCmd(event) {
    var paramList = {};
    for (var i = 0; i < this.rows.length; i++)
    {
      paramList[this.rows[i].parameter_name] = this.convertToValue(this.rows[i]);
    }

    var hazardous = false;
    this.api.get_cmd_hazardous(this.targetName, this.commandName, paramList).subscribe (
    (response) => {
      hazardous = response;
    
      if (hazardous) {
        this.displaySendHazardous = true;
      }
      else {
        var obs;
        if (this.ignoreRangeChecks) {
          obs = this.api.cmd_no_range_check(this.targetName, this.commandName, paramList);
        }
        else {
          obs = this.api.cmd(this.targetName, this.commandName, paramList);
        }

        obs.subscribe(
        (response) => {
          this.processCmdResponse(true, response);
        },
        (error) => {
          this.processCmdResponse(false, error);
        });
      }
    },
    (error) => {
      this.processCmdResponse(false, error);
    });
  }

  sendHazardousCmd(event) {
    this.displaySendHazardous = false;
    var paramList = {};
    for (var i = 0; i < this.rows.length; i++)
    {
      paramList[this.rows[i].parameter_name] = this.convertToValue(this.rows[i]);
    }

    var obs;
    if (this.ignoreRangeChecks) {
      obs = this.api.cmd_no_checks(this.targetName, this.commandName, paramList);
    }
    else {
      obs = this.api.cmd_no_hazardous_check(this.targetName, this.commandName, paramList);
    }

    obs.subscribe(
    (response) => {
      this.processCmdResponse(true, response);
    },
    (error) => {
      this.processCmdResponse(false, error);
    });
  }

  cancelHazardousCmd(event) {
    this.displaySendHazardous = false;
    this.status = 'Hazardous command not sent';
  }

  processCmdResponse(cmd_sent, response) {
    var msg = '';
    if (cmd_sent) {
      msg += 'cmd("' + response[0] + " " + response[1];
      var keys = Object.keys(response[2]);
      if (keys.length > 0) {
        msg += " with ";
        for (var i = 0; i < keys.length; i++) {
          var key = keys[i];
          msg += key + " " + this.convertToString(response[2][key]);
          if (i < keys.length-1) {
            msg += ", ";
          }
        }
      }
      msg += '") sent.'
      
      this.status = msg;
    }
    else {
      var context = 'sending ' + this.targetName + ' ' + this.commandName;
      this.displayError(context, response, true);
    }
  }

  displayError(context, error, showDialog=false) {
    this.status = 'Error ' + context + ' due to ' + error.name;
    if (error.message && error.message != "") {
      this.status += ': ';
      this.status += error.message;
    }
    if (showDialog) {
      this.displayErrorDialog = true
    }
  }

  ackError(event) {
    this.displayErrorDialog = false;
  }

  setupRawCmd() {
    this.api.get_interface_names().subscribe (
    (response) => {
      var interfaces = []
      for (var i = 0; i < response.length; i++) {
        interfaces.push({label: response[i], value: response[i]})
      }
      this.interfaces = interfaces;
      this.selectedInterface = interfaces[0].value;
      this.displaySendRaw = true;
    },
    (error) => {
      this.displaySendRaw = false;
      this.displayError("getting interface names", error, true);
    });
  }

  selectRawCmdFile(event) {
    this.rawCmdFile = event.target.files[0];
  }

  onLoad(event) {
    var bufView = new Uint8Array(event.target.result)
    var jstr = {"json_class":"String", "raw":[]}
    for (var i = 0; i < bufView.length; i++) {
      jstr.raw.push(bufView[i]);
    }
      
    this.api.send_raw(this.selectedInterface, jstr).subscribe (
    (response) => {
      this.displaySendRaw = false;
      this.status = "Sent " + bufView.length + " bytes to interface " + this.selectedInterface;
    },
    (error) => {
      this.displaySendRaw = false;
      this.displayError("sending raw data", error, true);
    });
  }

  sendRawCmd(event) {
  
    var self = this;
    var reader = new FileReader();
    reader.onload = function(e) {
      self.onLoad(e);
    }
    reader.onerror = function(e) {
      self.displaySendRaw = false;
      var target:any = e.target;
      self.displayError("sending raw data", target.error, true);
    }
    // TBD - use the other event handlers to implement a progress bar for the 
    // file upload.  Handle abort as well?
    //reader.onloadstart = function(e) {}
    //reader.onprogress = function(e) {}
    //reader.onloadend = function(e) {}
    //reader.onabort = function(e) {}

    reader.readAsArrayBuffer(this.rawCmdFile);
  }

  cancelRawCmd(event) {
    this.displaySendRaw = false;
    this.status = 'Raw command not sent';
  }
}
