import { Injectable } from '@angular/core';
import { HttpClient, HttpResponse } from '@angular/common/http';
import { Observable } from "rxjs/Observable";
import 'rxjs/add/operator/map'

export interface JsonRpcResponse {
  jsonrpc;
  id;
  result;
  error;
}

export interface GetTlmPacketItem {
  key;
  value;
  limits_state;
}

export interface GetTlmListItem {
  packet_name;
  description;
}

export interface GetTlmItemListItem {
  item_name;
  states;
  description;
}

export interface GetCmdListItem {
  command_name;
  description;
}

export interface GetCmdParamListItem {
  parameter_name;
  default_value;
  states;
  description;
  units_full;
  units;
  required_flag;
}

@Injectable()
export class CosmosApiService {

  id:number = 1;
  host:string = "http://localhost:3000";

  constructor(private http: HttpClient) { }

  // This is hacky Json-rpc for now.  Should probably use a jsonrpc library.
  exec(method, params) : Observable<any> {
    this.id = this.id + 1;
    return this.http.post<JsonRpcResponse>(this.host + "/api", {"jsonrpc": "2.0", "method": method, "params": params, "id": this.id}).map((data) => {
      if (data.error) {
        var err = new Error();
        err.name = data.error.data.class;
        err.message = data.error.data.message;
        console.log(data.error.data.backtrace.join("\n"));
        throw err;
      }
      return data.result;
    });
  }

  decode_cosmos_type(val) : any {
    if (val !== null && typeof val === 'object') {
      if (val.json_class == "Float" && val.raw) {
        if (val.raw == "NaN") {
          return NaN;
        }
        else if (val.raw == "Infinity") {
          return Infinity;
        }
        else if (val.raw == "-Infinity") {
          return -Infinity;
        }
      }
    }
    return null
  }

  encode_cosmos_type(val) : any {
    if (Number.isNaN(val)) {
      return {"json_class":"Float", "raw":"NaN"};
    }
    else if (val == Number.POSITIVE_INFINITY) {
      return {"json_class":"Float", "raw":"Infinity"};
    }
    else if (val == Number.NEGATIVE_INFINITY) {
      return {"json_class":"Float", "raw":"-Infinity"};
    }
    return null
  }


  // ***********************************************
  // The following APIs are used by the CmdTlmServer
  // ***********************************************
  get_all_interface_info() : Observable<any> {
    return this.exec("get_all_interface_info", []);
  }

  connect_interface(interface_name) : Observable<any> {
    return this.exec("connect_interface", [interface_name]);
  }

  disconnect_interface(interface_name) : Observable<any> {
    return this.exec("disconnect_interface", [interface_name]);
  }

  get_all_router_info() : Observable<any> {
    return this.exec("get_all_router_info", []);
  }

  connect_router(router_name) : Observable<any> {
    return this.exec("connect_router", [router_name]);
  }

  disconnect_router(router_name) : Observable<any> {
    return this.exec("disconnect_router", [router_name]);
  }

  get_all_target_info() : Observable<any> {
    return this.exec("get_all_target_info", []);
  }

  get_all_cmd_info() : Observable<any> {
    return this.exec("get_all_cmd_info", []);
  }

  get_all_tlm_info() : Observable<any> {
    return this.exec("get_all_tlm_info", []);
  }

  get_all_packet_logger_info() : Observable<any> {
    return this.exec("get_all_packet_logger_info", []);
  }

  start_logging() : Observable<any> {
    return this.exec("start_logging", []);
  }

  stop_logging() : Observable<any> {
    return this.exec("stop_logging", []);
  }

  start_cmd_log(log_writer_name) : Observable<any> {
    return this.exec("start_cmd_log", [log_writer_name]);
  }

  start_tlm_log(log_writer_name) : Observable<any> {
    return this.exec("start_tlm_log", [log_writer_name]);
  }

  stop_cmd_log(log_writer_name) : Observable<any> {
    return this.exec("stop_cmd_log", [log_writer_name]);
  }

  stop_tlm_log(log_writer_name) : Observable<any> {
    return this.exec("stop_tlm_log", [log_writer_name]);
  }

  get_server_status() : Observable<any> {
    return this.exec("get_server_status", []);
  }

  get_limits_sets() : Observable<any> {
    return this.exec("get_limits_sets", []);
  }

  set_limits_set(limits_set) : Observable<any> {
    return this.exec("set_limits_set", [limits_set]);
  }

  get_background_tasks() : Observable<any> {
    return this.exec("get_background_tasks", []);
  }

  start_background_task(name) : Observable<any> {
    return this.exec("start_background_task", [name]);
  }

  stop_background_task(name) : Observable<any> {
    return this.exec("stop_background_task", [name]);
  }

  // ***********************************************
  // End CmdTlmServer APIs
  // ***********************************************

  // Called by TargetPacketChooserComponent and TargetPacketItemChooserComponent
  get_target_list() : Observable<any> {
    return this.exec("get_target_list", []);
  }

  // Called by TargetPacketChooserComponent and TargetPacketItemChooserComponent
  get_tlm_list(target_name) : Observable<any> {
    return this.exec("get_tlm_list", [target_name]);
  }

  // Called by TargetPacketItemChooserComponent
  get_tlm_item_list(target_name, packet_name) : Observable<any> {
    return this.exec("get_tlm_item_list", [target_name, packet_name]);
  }

  // Called by PacketViewerComponent
  get_tlm_packet(target_name, packet_name, value_type) : Observable<any> {
    return this.exec("get_tlm_packet", [target_name, packet_name, value_type]).map((data) => {
      var len = data.length;
      var converted = null;
      for (var i = 0; i < len; i++) {
        converted = this.decode_cosmos_type(data[i][1]);
        if (converted !== null) {
          data[i][1] = converted;
        }
      }
      return data;
    });
  }

  // Called by CosmosScreenComponent
  get_tlm_values(items, value_types) : Observable<any> {
    return this.exec("get_tlm_values", [items, value_types]).map((data) => {
      var len = data[0].length;
      var converted = null;
      for (var i = 0; i < len; i++) {
        converted = this.decode_cosmos_type(data[0][i]);
        if (converted !== null) {
          data[0][i] = converted;
        }
      }
      return data;
    });
  }

  // Called by LimitsMonitorComponent
  tlm(target_name, packet_name, item_name) : Observable<any> {
    return this.exec("tlm", [target_name, packet_name, item_name]).map((data) => {
      var converted = this.decode_cosmos_type(data);
      if (converted !== null) {
        data = converted;
      }
      return data;
    });
  }

  // Called by CmdSenderComponent
  get_cmd_list(target_name) : Observable<any> {
    return this.exec("get_cmd_list", [target_name]);
  }

  // Called by CmdSenderComponent
  get_cmd_param_list(target_name, command_name) : Observable<any> {
    return this.exec("get_cmd_param_list", [target_name, command_name]).map((data) => {
      var len = data.length;
      var converted = null;
      for (var i = 0; i < len; i++) {
        converted = this.decode_cosmos_type(data[i][1]);
        if (converted !== null) {
          data[i][1] = converted;
        }
      }
      return data;
    });
  }

  // Called by CmdSenderComponent
  get_target_ignored_parameters(target_name) : Observable<any> {
    return this.exec("get_target_ignored_parameters", [target_name]);
  }

  // Implementation of functionality shared by cmd methods with param_lists.
  _cmd(method, target_name, command_name, param_list) : Observable<any> {
    var converted = null;
    for (var key in param_list) {
      if (param_list.hasOwnProperty(key)) {
        converted = this.encode_cosmos_type(param_list[key]);
        if (converted !== null) {
          param_list[key] = converted;
        }
      }
    }
    return this.exec(method, [target_name, command_name, param_list]);
  }

  // Called by CmdSenderComponent
  get_cmd_hazardous(target_name, command_name, param_list) : Observable<any> {
    return this._cmd("get_cmd_hazardous", target_name, command_name, param_list);
  }

  // Called by CmdSenderComponent
  cmd(target_name, command_name, param_list) : Observable<any> {
    return this._cmd("cmd", target_name, command_name, param_list);
  }

  // Called by CmdSenderComponent
  cmd_no_range_check(target_name, command_name, param_list) : Observable<any> {
    return this._cmd("cmd_no_range_check", target_name, command_name, param_list);
  }

  // Called by CmdSenderComponent
  cmd_no_hazardous_check(target_name, command_name, param_list) : Observable<any> {
    return this._cmd("cmd_no_hazardous_check", target_name, command_name, param_list);
  }

  // Called by CmdSenderComponent
  cmd_no_checks(target_name, command_name, param_list) : Observable<any> {
    return this._cmd("cmd_no_checks", target_name, command_name, param_list);
  }

  // Called by CmdSenderComponent
  get_interface_names() : Observable<any> {
    return this.exec("get_interface_names", []);
  }

  // Called by CmdSenderComponent
  send_raw(interface_name, data) : Observable<any> {
    return this.exec("send_raw", [interface_name, data]);
  }
}
