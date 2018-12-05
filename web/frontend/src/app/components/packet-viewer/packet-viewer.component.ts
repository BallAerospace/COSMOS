import { Component, OnInit, OnDestroy } from '@angular/core';
import { CosmosApiService, GetTlmPacketItem } from '../../services/cosmos-api.service';
import { Observable } from "rxjs/Observable";
import { Subscription } from "rxjs/Subscription";
import "rxjs/add/observable/interval";

@Component({
  selector: 'cosmos-packet-viewer',
  templateUrl: './packet-viewer.component.html',
  styleUrls: ['./packet-viewer.component.css']
})
export class PacketViewerComponent implements OnInit, OnDestroy {

  updater:Subscription = null;
  targetName:string = '';
  packetName:string = '';
  valueType:string = 'WITH_UNITS';
  refreshInterval:number = 1000;
  rows:GetTlmPacketItem[] = [];
  menuItems = [];
  withUnitsIcon = 'fa-check-circle-o';
  formattedIcon = 'fa-circle-o';
  convertedIcon = 'fa-circle-o';
  rawIcon = 'fa-circle-o';
  displayOptions:boolean = false;

  constructor(private api: CosmosApiService) { }

  buildMenu() {
    var fileMenuItems = {
      label: 'File', items:
        [{label: 'Options', command: () => {this.displayOptions = true}}]
    };
    var viewMenuItems = {
      label: 'View', items:
      [
        {label: 'WITH_UNITS', icon: this.withUnitsIcon, command: () => {this.selectWithUnits()} },
        {label: 'FORMATTED', icon: this.formattedIcon, command: () => {this.selectFormatted()} },
        {label: 'CONVERTED', icon: this.convertedIcon, command: () => {this.selectConverted()} },
        {label: 'RAW', icon: this.rawIcon, command: () => {this.selectRaw()} }
      ]
    };
    this.menuItems = [fileMenuItems, viewMenuItems];
  }

  resetIcons() {
    this.withUnitsIcon = 'fa-circle-o';
    this.formattedIcon = 'fa-circle-o';
    this.convertedIcon = 'fa-circle-o';
    this.rawIcon = 'fa-circle-o';
  }

  selectWithUnits() {
    if (this.valueType !== 'WITH_UNITS') {
      this.valueType = 'WITH_UNITS';
      this.resetIcons();
      this.withUnitsIcon = 'fa-check-circle-o';
      this.buildMenu();
      this.changeUpdater(false);
    }
  }

  selectFormatted() {
    if (this.valueType !== 'FORMATTED') {
      this.valueType = 'FORMATTED';
      this.resetIcons();
      this.formattedIcon = 'fa-check-circle-o';
      this.buildMenu();
      this.changeUpdater(false);
    }
  }

  selectConverted() {
    if (this.valueType !== 'CONVERTED') {
      this.valueType = 'CONVERTED';
      this.resetIcons();
      this.convertedIcon = 'fa-check-circle-o';
      this.buildMenu();
      this.changeUpdater(false);
    }
  }

  selectRaw() {
    if (this.valueType !== 'RAW') {
      this.valueType = 'RAW';
      this.resetIcons();
      this.rawIcon = 'fa-check-circle-o';
      this.buildMenu();
      this.changeUpdater(false);
    }
  }

  ngOnInit() {
    this.buildMenu();
  }

  packetChanged(event) {
    this.targetName = event.targetName;
    this.packetName = event.packetName;
    this.changeUpdater(true);
  }

  changeUpdater(clearExisting:boolean) {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
    if (clearExisting) {
      this.rows = [];
    }

    this.updater = Observable.interval(this.refreshInterval).subscribe(x => {
      this.api.get_tlm_packet(this.targetName, this.packetName, this.valueType).subscribe((data:GetTlmPacketItem[]) => {
        this.rows = data;
      });
    });
  }

  intervalChanged() {
    console.log(this.refreshInterval);
    this.changeUpdater(false);
  }

  ngOnDestroy() {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
  }

}
