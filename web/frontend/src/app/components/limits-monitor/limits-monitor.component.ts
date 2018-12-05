import { Component, OnInit, OnDestroy } from '@angular/core';
import { CosmosApiService, GetTlmPacketItem } from '../../services/cosmos-api.service';
import * as ActionCable from 'actioncable';
import * as moment from 'moment';

@Component({
  selector: 'cosmos-limits-monitor',
  templateUrl: './limits-monitor.component.html',
  styleUrls: ['./limits-monitor.component.css']
})
export class LimitsMonitorComponent implements OnInit, OnDestroy {

  readonly maxArrayLength = 30;
  private cable: ActionCable.Cable;
  private subscription: ActionCable.Channel;
  limitsEvents:any[];
  limitsEventMessages:any[];

  constructor(private api: CosmosApiService) {}

  appendEventMessage(eventMessage) {
    this.limitsEventMessages.push(eventMessage);
    while (this.limitsEventMessages.length > this.maxArrayLength) { this.limitsEventMessages.shift() };
  }

  limitsChange(string, event) {
    var target_name = event[2][0];
    var packet_name = event[2][1];
    var item_name = event[2][2];
    var state = event[2][4];
    var color = "BLACK";
    var item = [target_name, packet_name, item_name];

    switch (state) {
      case "YELLOW":
      case "YELLOW_HIGH":
      case "YELLOW_LOW":
        string = string + " WARN: ";
        color = "YELLOW";
        //out_of_limit(item);
        break;
      case "RED":
      case "RED_HIGH":
      case "RED_LOW":
        string = string + " ERROR: ";
        color = "RED";
        //out_of_limit(item);
        break;
      case "GREEN_HIGH":
      case "GREEN_LOW":
        string = string + " INFO: ";
        color = "GREEN";
        //out_of_limit(item) if @monitor_operational
        break;
      case "GREEN":
        string = string + " INFO: ";
        color = "GREEN";
        break;
      case "BLUE":
        string = string + " INFO: ";
        color = "BLUE";
        break;
      default:
        string = string + " INFO: ";
        color = "BLACK";
        break;
    }
    this.api.tlm(target_name, packet_name, item_name).subscribe((value) => {
      if (state != null) {
        string = string + target_name + " " + packet_name + " " + item_name + " = " + value + " is " + state;
      } else {
        string = string + "Limits checking disabled on " + target_name + " " + packet_name + " " + item_name + " with current value: " + value
      }
      this.appendEventMessage([string, color]);
    });
  }

  processEvent(event) {
    var color = "BLACK";
    var string = moment(event[0]).format("YYYY-MM-DD HH:mm:ss");

    switch (event[1]) {
      case "LIMITS_CHANGE":
        this.limitsChange(string, event);
        break;
      case "LIMITS_SET":
        string = string + " INFO: Limits Set Changed to: " + event[2];
        this.appendEventMessage([string, color]);
        break;
      case "LIMITS_SETTINGS":
        string = string + " INFO: Limits Setting Changed: [" + event[2].join(", ") + "]";
        this.appendEventMessage([string, color]);
        break;
      case "STALE_PACKET":
        string = string + " INFO: Packet " + event[2][0] + " " + event[2][1] + " is STALE";
        this.appendEventMessage([string, color]);
        break;
      case "STALE_PACKET_RCVD":
        string = string + " INFO: Packet " + event[2][0] + " " + event[2][1] + " is no longer STALE";
        this.appendEventMessage([string, color]);
        break;
      default:
        color = "RED";
        string = string + " " + "ERROR: Unknown limits event: " + event[1];
        this.appendEventMessage([string, color]);
        break;
    }
  }

  private received(event: any) {
    event.unshift(Date.now());
    this.limitsEvents.push(event);
    while (this.limitsEvents.length > this.maxArrayLength) { this.limitsEvents.shift() };
    this.processEvent(event);
  }

  ngOnInit() {
    this.limitsEvents = [];
    this.limitsEventMessages = [];
    this.cable = ActionCable.createConsumer('ws://localhost:3000/cable');
    this.subscription = this.cable.subscriptions.create(
      'LimitsEventChannel',
      {
        received: (data) => this.received(data)
      });
  }

  ngOnDestroy() {
    this.subscription.unsubscribe();
    this.cable.disconnect();
  }
}
