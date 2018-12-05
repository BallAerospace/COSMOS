import { Component, OnInit, OnDestroy } from '@angular/core';
import { CosmosApiService, GetTlmListItem } from '../../services/cosmos-api.service';
import { Observable } from "rxjs/Observable";
import { Subscription } from "rxjs/Subscription";
import "rxjs/add/observable/interval";

@Component({
  selector: 'routers',
  template: `
    <p-dataTable [value]="routers" [immutable]="false" [tableStyle]="{'table-layout':'auto'}" sortField="name" sortOrder="1">
      <p-column field="name" header="Router" [sortable]="true"></p-column>
      <p-column>
        <!-- TODO: Implement interface.disable_disconnect -->
        <ng-template pTemplate="header">Connect / Disconnect</ng-template>
        <ng-template let-router="rowData" pTemplate="body">
          <button type="button" pButton label="{{router['connect']}}" (click)="routerConnect(router['name'], router['connect'])"></button>
        </ng-template>
      </p-column>
      <p-column field="connected" header="Connected?" [sortable]="true"></p-column>
      <p-column field="clients" header="Clients" [sortable]="true"></p-column>
      <p-column field="txqsize" header="Tx Q Size" [sortable]="true"></p-column>
      <p-column field="rxqsize" header="Rx Q Size" [sortable]="true"></p-column>
      <p-column field="txbytes" header="Tx Bytes" [sortable]="true"></p-column>
      <p-column field="rxbytes" header="Rx Bytes" [sortable]="true"></p-column>
      <p-column field="txpkts" header="Tx Pkts" [sortable]="true"></p-column>
      <p-column field="rxpkts" header="Rx Pkts" [sortable]="true"></p-column>
    </p-dataTable>
    `
})

export class RoutersComponent implements OnInit, OnDestroy {
  routers: any[] = [];
  updater:Subscription = null;
  refreshInterval:number = 1000;

  constructor(private api: CosmosApiService) { }

  ngOnInit() {
    this.changeUpdater()
  }

  routerConnect(name, connect) {
    if (connect == 'Connect') {
      this.api.connect_router(name).subscribe((result) => {
        // Result is a don't care. We'll poll for the actual status.
      })
    }
    if (connect == 'Disconnect') {
      this.api.disconnect_router(name).subscribe((result) => {
        // Result is a don't care. We'll poll for the actual status.
      })
    }
  }

  changeUpdater() {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
    this.updater = Observable.interval(this.refreshInterval).subscribe(x => {
      this.api.get_all_router_info().subscribe((info) => {
        this.routers = [] // Clear out the old routers array
        for (var i = 0; i < info.length; i++) {
          let connect = ''
          if (info[i][1] == 'DISCONNECTED') {
            connect = 'Connect'
          } else {
            connect = 'Disconnect'
          }
          this.routers.push({ name: info[i][0], connect: connect, connected: info[i][1],
            clients: info[i][2], txqsize: info[i][3], rxqsize: info[i][4], txbytes: info[i][5],
            rxbytes: info[i][6], rxpkts: info[i][7], txpkts: info[i][8] });
        }
      })
    })
  }

  ngOnDestroy() {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
  }
}
