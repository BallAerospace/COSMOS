import { Component, EventEmitter, Input, Output, OnInit } from '@angular/core';
import { CosmosApiService, GetCmdListItem } from '../../services/cosmos-api.service';
import 'rxjs/add/operator/retry'

@Component({
  selector: 'cosmos-target-command-chooser',
  template: `
    <p-dropdown (onChange)="targetNameChanged($event)" [options]="targetNames" [(ngModel)]="selectedTargetName" [style]="{'width':'45%', 'float':'left', 'margin-right':'5px'}"></p-dropdown>
    <p-dropdown (onChange)="commandNameChanged($event)" [options]="commandNames" [(ngModel)]="selectedCommandName" [style]="{'width':'45%', 'float':'left', 'margin-right':'5px'}"></p-dropdown>
    <button pButton type="button" label="Send" (click)="cmdSent($event)" [disabled]="disabled"></button>
    <p *ngIf="!disabled" style="margin-top:5px;">Description: {{description}}</p>
  `
})
export class TargetCommandChooserComponent implements OnInit {

  @Input() disabled:boolean = true;
  @Output() onSet = new EventEmitter<{targetName:string,commandName:string}>();
  @Output() onCmdSent = new EventEmitter<{targetName:string,commandName:string}>();
  @Output() onStatusChange = new EventEmitter<{status:string}>();

  targetNames = [];
  commandNames = [];
  selectedTargetName:string = '';
  selectedCommandName:string = '';
  description:string = '';
  cmd_list_items:GetCmdListItem[] = [];
  loadingNames = [{label: "Loading...", value: "Loading..."}];
  status:string = '';

  constructor(private api: CosmosApiService) { }

  ngOnInit() {
    this.updateTargets();
  }

  updateTargets() {
    this.disabled = true;
    this.targetNames = this.loadingNames;
    this.commandNames = this.loadingNames;
    this.updateStatus('Attempting to get target list from server...');
    this.api.get_target_list().retry().subscribe(data => {
      var targetNames = [];
      var arrayLength = data.length;
      for (var i = 0; i < arrayLength; i++) {
        targetNames.push({label: data[i], value: data[i]})
      }
      this.targetNames = targetNames;
      this.selectedTargetName = targetNames[0].value;

      this.updateCommands();
    });
  }

  updateCommands() {
    this.disabled = true;
    this.commandNames = this.loadingNames;
    this.updateStatus('Attempting to get command list from server...');
    this.api.get_cmd_list(this.selectedTargetName).retry().subscribe(commands => {
      this.cmd_list_items = commands;
      var commandNames = [];
      var arrayLength = commands.length;
      for (var i = 0; i < arrayLength; i++) {
        commandNames.push({label: commands[i][0], value: commands[i][0]})
      }
      this.commandNames = commandNames;
      this.selectedCommandName = commandNames[0].value;
      this.description = this.cmd_list_items[0][1];
      this.updateStatus('');
      this.disabled = false;
      this.onSet.emit({targetName: this.selectedTargetName, commandName:this.selectedCommandName});
    });
  }

  updateStatus(status:string) {
    this.status = status;
    this.onStatusChange.emit({status: this.status});
  }

  targetNameChanged(event) {
    this.selectedTargetName = event.value;
    this.updateCommands();
  }

  commandNameChanged(event) {
    var commandNames = [];
    var arrayLength = this.cmd_list_items.length;
    for (var i = 0; i < arrayLength; i++) {
      if (event.value === this.cmd_list_items[i][0]) {
        this.selectedCommandName = this.cmd_list_items[i][0];
        this.description = this.cmd_list_items[i][1];
        this.onSet.emit({targetName: this.selectedTargetName, commandName: this.selectedCommandName});
        break;
      }
    }
  }

  cmdSent(event) {
    this.onCmdSent.emit({targetName: this.selectedCommandName, commandName: this.selectedCommandName});
  }
}
