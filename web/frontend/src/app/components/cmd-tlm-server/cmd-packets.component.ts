import { Component, OnInit, OnDestroy } from '@angular/core';
import { CosmosApiService, GetTlmListItem } from '../../services/cosmos-api.service';
import { Observable } from "rxjs/Observable";
import { Subscription } from "rxjs/Subscription";
import "rxjs/add/observable/interval";

@Component({
  selector: 'cmd-packets',
  template: `
    <p-dataTable [value]="commands" [immutable]="true" [tableStyle]="{'table-layout':'auto'}" sortField="target" sortOrder="1">
      <p-column field="target" header="Target Name" [sortable]="true"></p-column>
      <p-column field="packet" header="Packet Name" [sortable]="true"></p-column>
      <p-column field="pktcnt" header="Packet Count" [sortable]="true"></p-column>
    </p-dataTable>
    `
})

export class CmdPacketsComponent implements OnInit, OnDestroy {
  commands: any[] = [];
  updater:Subscription = null;
  refreshInterval:number = 1000;

  constructor(private api: CosmosApiService) { }

  ngOnInit() {
    this.changeUpdater()
  }

  changeUpdater() {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
    this.updater = Observable.interval(this.refreshInterval).subscribe(x => {
      this.api.get_all_cmd_info().subscribe(info => {
        this.commands = [] // Clear out the old targets array
        for (var i = 0; i < info.length; i++) {
          this.commands.push({ target: info[i][0], packet: info[i][1], pktcnt: info[i][2] })
        }
      })
    });
  }

  ngOnDestroy() {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
  }
}
