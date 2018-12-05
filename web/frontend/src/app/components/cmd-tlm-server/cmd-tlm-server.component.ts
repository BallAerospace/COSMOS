import { Component } from '@angular/core';
import { TabViewModule } from 'primeng/primeng';
import { InterfacesComponent } from './interfaces.component'
import { CosmosApiService } from '../../services/cosmos-api.service';
import * as ActionCable from 'actioncable';
import * as moment from 'moment';

@Component({
  selector: 'cosmos-cmd-tlm-server',
  template: `
    <div class="container" style="margin-top:20px;margin-bottom:20px;">
      <p-tabView (onChange)="handleChange($event)">
        <p-tabPanel header="Interfaces">
          <interfaces *ngIf="activeTab === 0"></interfaces>
        </p-tabPanel>
        <p-tabPanel header="Targets">
          <targets *ngIf="activeTab === 1"></targets>
        </p-tabPanel>
        <p-tabPanel header="Cmd Packets">
          <cmd-packets *ngIf="activeTab === 2"></cmd-packets>
        </p-tabPanel>
        <p-tabPanel header="Tlm Packets">
          <tlm-packets *ngIf="activeTab === 3"></tlm-packets>
        </p-tabPanel>
        <p-tabPanel header="Routers">
          <routers *ngIf="activeTab === 4"></routers>
        </p-tabPanel>
        <p-tabPanel header="Logging">
          <logging *ngIf="activeTab === 5"></logging>
        </p-tabPanel>
        <p-tabPanel header="Status">
          <status *ngIf="activeTab === 6"></status>
        </p-tabPanel>
      </p-tabView>
      <limits-events [eventMessages]="serverMessages"></limits-events>
    </div>
  `
})

export class CmdTlmServerComponent {
  readonly maxArrayLength = 30;
  private cable: ActionCable.Cable;
  private subscription: ActionCable.Channel;
  serverMessages:any[];
  activeTab = 0;

  constructor(private api: CosmosApiService) {}

  private received(message: any) {
    this.serverMessages.push([message[0], message[1]]);
    while (this.serverMessages.length > this.maxArrayLength) { this.serverMessages.shift() };
  }

  ngOnInit() {
    this.serverMessages = [];
    this.cable = ActionCable.createConsumer('ws://localhost:3000/cable');
    this.subscription = this.cable.subscriptions.create(
      'ServerMessagesChannel',
      {
        received: (data) => this.received(data)
      });
  }

  ngOnDestroy() {
    this.subscription.unsubscribe();
    this.cable.disconnect();
  }

  handleChange(e) {
    this.activeTab = e.index;
  }
}
