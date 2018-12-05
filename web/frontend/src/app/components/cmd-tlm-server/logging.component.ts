import { Component, OnInit, OnDestroy } from '@angular/core';
import { CosmosApiService, GetTlmListItem } from '../../services/cosmos-api.service';
import { Observable } from "rxjs/Observable";
import { Subscription } from "rxjs/Subscription";
import "rxjs/add/observable/interval";

@Component({
  selector: 'logging',
  template: `
    <div class="row">
      <div class="col">
        <button type="button" pButton label="Start Logging on All" (click)="startLogging()"></button>
      </div>
      <div class="col">
        <button type="button" pButton label="Stop Logging on All" (click)="stopLogging()"></button><br/>
      </div>
    </div>
    <div class="row">
      <div class="col">
        <button type="button" pButton label="Start Telemetry Logging on All" (click)="startTlmLogging('ALL')"></button>
      </div>
      <div class="col">
        <button type="button" pButton label="Stop Telemetry Logging on All" (click)="stopTlmLogging('ALL')"></button>
      </div>
    </div>
    <div class="row">
      <div class="col">
        <button type="button" pButton label="Start Command Logging on All" (click)="startCmdLogging('ALL')"></button>
      </div>
      <div class="col">
        <button type="button" pButton label="Stop Command Logging on All" (click)="stopCmdLogging('ALL')"></button>
      </div>
    </div>

    <p-fieldset *ngFor="let logger of loggers" legend="{{logger[0]}}">
      <p>Interfaces: {{logger[1]}}</p>
      <p>Cmd Logging: {{logger[2]}}</p>
      <p>Cmd Queue Size: {{logger[3]}}</p>
      <p>Cmd Filename: {{logger[4]}}</p>
      <p>Cmd File Size: {{logger[5]}}</p>
      <p>Tlm Logging: {{logger[6]}}</p>
      <p>Tlm Queue Size: {{logger[7]}}</p>
      <p>Tlm Filename: {{logger[8]}}</p>
      <p>Tlm File Size: {{logger[9]}}</p>
      <div class="row">
        <div class="col">
          <button type="button" pButton label="Start Cmd Logging" (click)="startCmdLogging(logger[0])"></button>
        </div>
        <div class="col">
          <button type="button" pButton label="Start Tlm Logging" (click)="startTlmLogging(logger[0])"></button>
        </div>
        <div class="col">
          <button type="button" pButton label="Stop Cmd Logging" (click)="stopCmdLogging(logger[0])"></button>
        </div>
        <div class="col">
          <button type="button" pButton label="Stop Tlm Logging" (click)="stopTlmLogging(logger[0])"></button>
        </div>
      </div>
    </p-fieldset>
    `,
  styles: [`
    p { margin: 0px; padding: 0px; }
    .row { padding-bottom: 5px; }
    legend { margin: 0px; padding: 0px; font-size: 8px; }
    .ui-fieldset-legend { margin: 0px; padding: 0px; font-size: 8px; }
  `]
})

export class LoggingComponent implements OnInit, OnDestroy {
  loggers: any[] = [];
  updater:Subscription = null;
  refreshInterval:number = 1000;

  constructor(private api: CosmosApiService) { }

  ngOnInit() {
    this.changeUpdater()
  }

  startLogging() {
    this.api.start_logging().subscribe((result) => { })
  }

  stopLogging() {
    this.api.stop_logging().subscribe((result) => { })
  }

  startTlmLogging(log_writer_name) {
    this.api.start_tlm_log(log_writer_name).subscribe((result) => { })
  }

  stopTlmLogging(log_writer_name) {
    this.api.stop_tlm_log(log_writer_name).subscribe((result) => { })
  }

  startCmdLogging(log_writer_name) {
    this.api.start_cmd_log(log_writer_name).subscribe((result) => { })
  }

  stopCmdLogging(log_writer_name) {
    this.api.stop_cmd_log(log_writer_name).subscribe((result) => { })
  }

  changeUpdater() {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
    this.updater = Observable.interval(this.refreshInterval).subscribe(x => {
      this.api.get_all_packet_logger_info().subscribe((info) => {
        this.loggers = info
        // console.log(info)
        // this.loggers = [] // Clear out the old loggers array
        // for (var i = 0; i < info.length; i++) {
        //   this.loggers.push(info[i])
        // }
      })
    });
  }

  ngOnDestroy() {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
  }
}
