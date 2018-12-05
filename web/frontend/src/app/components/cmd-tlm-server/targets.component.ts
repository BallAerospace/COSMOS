import { Component, OnInit, OnDestroy } from '@angular/core';
import { CosmosApiService, GetTlmListItem } from '../../services/cosmos-api.service';
import { Observable } from "rxjs/Observable";
import { Subscription } from "rxjs/Subscription";
import "rxjs/add/observable/interval";

@Component({
  selector: 'targets',
  template: `
    <p-dataTable [value]="targets" [tableStyle]="{'table-layout':'auto'}" sortField="name" sortOrder="1">
      <p-column field="name" header="Target Name" [sortable]="true"></p-column>
      <p-column field="interface" header="Interface" [sortable]="true"></p-column>
      <p-column field="cmdcnt" header="Command Count" [sortable]="true"></p-column>
      <p-column field="tlmcnt" header="Telemetry Count" [sortable]="true"></p-column>
    </p-dataTable>
    `
})

export class TargetsComponent implements OnInit, OnDestroy {
  targets: any[] = [];
  updater:Subscription = null;
  refreshInterval:number = 1000;

  constructor(private api: CosmosApiService) { }

  ngOnInit() {
    this.changeUpdater()
  }

  changeUpdater() {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
    this.updater = Observable.interval(this.refreshInterval).subscribe(x => {
      this.api.get_all_target_info().subscribe((info) => {
        this.targets = [] // Clear out the old targets array
        for (var i = 0; i < info.length; i++) {
          this.targets.push({ name: info[i][0], interface: info[i][1],
            cmdcnt: info[i][2], tlmcnt: info[i][3] });
        }
      })
    });
  }

  ngOnDestroy() {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
  }
}
