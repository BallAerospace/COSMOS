import { Component, EventEmitter, Output, OnInit } from '@angular/core';
import { CosmosApiService, GetTlmListItem } from '../../../services/cosmos-api.service';

@Component({
  selector: 'cosmos-target-packet-chooser',
  templateUrl: './target-packet-chooser.component.html',
  styleUrls: ['./target-packet-chooser.component.css']
})
export class TargetPacketChooserComponent implements OnInit {

  @Output() onSet = new EventEmitter<{targetName:string,packetName:string}>();

  targetNames = [];
  packetNames = [];
  selectedTargetName:string = '';
  selectedPacketName:string = '';
  description = '';
  tlm_list_items:GetTlmListItem[] = [];

  constructor(private api: CosmosApiService) { }

  ngOnInit() {
    this.api.get_target_list().subscribe(data => {
      var targetNames = [];
      var arrayLength = data.length;
      for (var i = 0; i < arrayLength; i++) {
        targetNames.push({label: data[i], value: data[i]})
      }
      this.targetNames = targetNames;
      this.selectedTargetName = targetNames[0].value;

      this.updatePackets();
    });
  }

  updatePackets() {
    this.api.get_tlm_list(this.selectedTargetName).subscribe(packets => {
      this.tlm_list_items = packets;
      var packetNames = [];
      var arrayLength = packets.length;
      for (var i = 0; i < arrayLength; i++) {
        packetNames.push({label: packets[i][0], value: packets[i][0]})
      }
      this.packetNames = packetNames;
      this.selectedPacketName = packetNames[0].value;
      this.description = this.tlm_list_items[0][1];
      this.onSet.emit({targetName: this.selectedTargetName, packetName:this.selectedPacketName});
    });
  }

  targetNameChanged(event) {
    this.selectedTargetName = event.value;
    this.updatePackets();
  }

  packetNameChanged(event) {
    var packetNames = [];
    var arrayLength = this.tlm_list_items.length;
    for (var i = 0; i < arrayLength; i++) {
      if (event.value === this.tlm_list_items[i][0]) {
        this.selectedPacketName = this.tlm_list_items[i][0];
        this.description = this.tlm_list_items[i][1];
        this.onSet.emit({targetName: this.selectedTargetName, packetName: this.selectedPacketName});
        break;
      }
    }
  }

}
