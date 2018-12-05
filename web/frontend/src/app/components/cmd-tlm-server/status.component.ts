import { Component, OnInit, OnDestroy } from '@angular/core';
import { CosmosApiService } from '../../services/cosmos-api.service';
import { SelectItem } from 'primeng/primeng';
import { Observable } from "rxjs/Observable";
import { Subscription } from "rxjs/Subscription";
import "rxjs/add/observable/interval";

@Component({
  selector: 'status',
  template: `
    <p>Limits Set: <p-dropdown [options]="limitsSets" [(ngModel)]="selectedLimitsSet" (onChange)="setLimits($event)" [autoWidth]="false"></p-dropdown></p>
    <p>API Status</p>
    <p-dataTable [value]="status" [tableStyle]="{'table-layout':'auto'}">
      <p-column field="port" header="Port"></p-column>
      <p-column field="clients" header="Clients"></p-column>
      <p-column field="requests" header="Requests"></p-column>
      <p-column field="avgTime" header="Avg Request Time"></p-column>
      <p-column field="threads" header="Server Threads"></p-column>
    </p-dataTable>
    <br/>
    <p>Background Tasks</p>
    <p-dataTable [value]="backgroundTasks" [immutable]="false" [tableStyle]="{'table-layout':'auto'}" sortField="name" sortOrder="1">
      <p-column field="name" header="Name" [sortable]="true"></p-column>
      <p-column field="state" header="State" [sortable]="true"></p-column>
      <p-column field="status" header="Status" [sortable]="true"></p-column>
      <p-column>
        <ng-template pTemplate="header">Control</ng-template>
        <ng-template let-task="rowData" pTemplate="body">
          <button type="button" pButton label="{{task['control']}}" (click)="taskControl(task['name'], task['control'])"></button>
        </ng-template>
      </p-column>
    </p-dataTable>
    `,
})

export class StatusComponent implements OnInit, OnDestroy {
  limitsSets: any[] = [];
  selectedLimitsSet: string;
  status: any[] = [];
  backgroundTasks: any[] = [];
  updater:Subscription = null;
  refreshInterval:number = 1000;

  constructor(private api: CosmosApiService) { }

  taskControl(name, state) {
    if (state == 'Start') {
      console.log("name:"+name+" state:"+state)
      this.api.start_background_task(name).subscribe((result) => {
        // Result is a don't care. We'll poll for the actual status.
      })
    } else if (state == 'Stop') {
      console.log("name:"+name+" state:"+state)
      this.api.stop_background_task(name).subscribe((result) => {
        // Result is a don't care. We'll poll for the actual status.
      })
    }
  }

  ngOnInit() {
    this.api.get_limits_sets().subscribe(limits => {
      for (let name of limits) {
        this.limitsSets.push({label:name, value:name});
      }
      this.initialBackgroundTasks()
    })
  }

  initialBackgroundTasks() {
    this.api.get_background_tasks().subscribe(tasks => {
      for (var i = 0; i < tasks.length; i++) {
        var controlState = "Stop"
        if (tasks[i][1] == "no thread" || tasks[i][1] == "complete") {
          controlState = "Start"
        }
        this.backgroundTasks.push({name:tasks[i][0], state:tasks[i][1],
          status:tasks[i][2], control:controlState})
      }
      this.changeUpdater()
    })
  }

  changeUpdater() {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
    this.updater = Observable.interval(this.refreshInterval).subscribe(x => {
      this.api.get_server_status().subscribe(status => {
        this.selectedLimitsSet = status[0]
        this.status = [] // Clear out the old apiStatus array
        this.status.push({ port: status[1], clients: status[2], requests: status[3], avgTime: status[4], threads: status[5] })
      })
      this.api.get_background_tasks().subscribe(tasks => {
        for (var i = 0; i < tasks.length; i++) {
          this.backgroundTasks[i]['name'] = tasks[i][0]
          this.backgroundTasks[i]['state'] = tasks[i][1]
          this.backgroundTasks[i]['status'] = tasks[i][2]
          if (tasks[i][1] == "no thread" || tasks[i][1] == "complete") {
            this.backgroundTasks[i]['control'] = "Start"
          } else {
            this.backgroundTasks[i]['control'] = "Stop"
          }
        }
      })
    })
  }

  setLimits(event) {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
    this.api.set_limits_set(event.value).subscribe(result => {
      this.changeUpdater()
    })
  }

  ngOnDestroy() {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
  }
}
