import { Injectable } from '@angular/core';

export class ConfigParserError {
  keyword:string;
  parameters:string[];
  filename:string;
  line:string;
  line_number:number;
  usage:string;
  url:string;

  constructor(config_parser, message = "Configuration Error", usage = "", url = "") {
    this.keyword = config_parser.keyword;
    this.parameters = config_parser.parameters;
    this.filename = config_parser.filename;
    this.line = config_parser.line;
    this.line_number = config_parser.line_number;
    this.usage = usage;
    this.url = url;  
  }
}

@Injectable()
export class ConfigParserService {

  keyword:string = null;
  parameters:string[] = [];
  filename:string = "";
  line:string = "";
  line_number:number = 0;
  url:string = "http://cosmosrb.com/docs/home";

  constructor() { }

  verify_num_parameters(min_num_params, max_num_params, usage = "") {
    // This syntax works with 0 because each doesn't return any values
    // for a backwards range
    for (var index = 1; index <= min_num_params; index++) {
      // If the parameter is nil (0 based) then we have a problem
      if (this.parameters[index - 1] === undefined) {
        throw new ConfigParserError(this, `Not enough parameters for ${this.keyword}.`, usage, this.url);
      }
    }
    // If they pass null for max_params we don't check for a maximum number
    if ((max_num_params) && (!this.parameters[max_num_params] === undefined)) {
      throw new ConfigParserError(this, `Too many parameters for ${this.keyword}.`, usage, this.url);
    }
  }

  remove_quotes(string:string) {
    if (string.length < 2) { return string }
    var first_char = string.charAt(0);
    if ((first_char !== '"') && (first_char !== "'")) { return string }
    var last_char = string.charAt(string.length - 1);
    if (first_char !== last_char) { return string }
    return string.substring(1,string.length - 1);
  }

  scan_string(string:string, rx:any) {
    if (!rx.global) throw "rx must have 'global' flag set";
    var r = [];
    string.replace(rx, function(match, args):string {
      r.push(match);
      return match;
    });
    return r;
  }

  parse_string(input_string:string, original_filename:string, yield_non_keyword_lines:boolean, remove_quotes:boolean, handler:any) {
    var line_continuation = false;
    this.line = "";
    this.keyword = null;
    this.parameters = [];
    this.filename = original_filename;

    // Break string in to lines
    var lines = input_string.split('\n');
    var numLines = lines.length;

    for (var i = 0; i < numLines; i++) {
      this.line_number = i + 1;
      var line = lines[i];

      line = line.trim();

      var rx = /("([^\\"]|\\.)*")|('([^\\']|\\.)*')|\S+/g;
      var data = this.scan_string(line, rx);

      var first_item = "";
      if (data.length > 0) {
        first_item = first_item + data[0];
      }

      if (line_continuation) {
        this.line = this.line + line;
        // Carry over keyword and parameters
      } else {
        this.line = line;
        if ((first_item.length === 0) || (first_item.charAt(0) === '#')) {
          this.keyword = null;
        } else {
          this.keyword = first_item.toUpperCase();
        }
        this.parameters = [];
      }

      // Ignore comments and blank lines
      if (this.keyword === null) {
        if ((yield_non_keyword_lines) && (!line_continuation)) {
          handler(this.keyword, this.parameters);
        }
        continue;
      }

      if (line_continuation) {
        if (remove_quotes) {
          this.parameters.push(this.remove_quotes(first_item));
        } else {
          this.parameters.push(first_item);
        }
        line_continuation = false;
      }

      var length = data.length;
      if (length > 1) {
        for (var index = 1; index < length; index++) {
          var string = data[index];

          // Don't process trailing comments such as:
          // KEYWORD PARAM #This is a comment
          // But still process Ruby string interpolations such as:
          // KEYWORD PARAM #{var}
          if ((string.length > 0) && (string.charAt(0) === '#')) {
            if (!((string.length > 1) && (string.charAt(1) === '{'))) {
              break;
            }
          }

          // If the string is simply '&' and its the last string then its a line continuation so break the loop
          if ((string.length === 1) && (string.charAt(0) === '&') && (index === (length - 1))) {
            line_continuation = true;
            continue;
          }

          line_continuation = false;
          if (remove_quotes) {
            this.parameters.push(this.remove_quotes(string));
          } else {
            this.parameters.push(string);
          }
        }
      }

      // If we detected a line continuation while going through all the
      // strings on the line then we strip off the continuation character and
      // return to the top of the loop to continue processing the line.
      if (line_continuation) {
        // Strip the continuation character
        if (this.line.length >= 1) {
          this.line = this.line.substring(0, this.line.length - 1);
        } else {
          this.line = "";
        }
        continue;
      }

      handler(this.keyword, this.parameters);

    } // for

  } // parse_string

} // class ConfigParserService
