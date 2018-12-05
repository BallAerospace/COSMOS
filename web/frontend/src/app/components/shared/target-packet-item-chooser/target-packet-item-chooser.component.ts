import { Component, EventEmitter, Output, OnInit } from '@angular/core';
import { CosmosApiService, GetTlmListItem, GetTlmItemListItem } from '../../../services/cosmos-api.service';

@Component({
  selector: 'cosmos-target-packet-item-chooser',
  templateUrl: './target-packet-item-chooser.component.html',
  styleUrls: ['./target-packet-item-chooser.component.css']
})
export class TargetPacketItemChooserComponent implements OnInit {

  @Output() onSet = new EventEmitter<{targetName:string,packetName:string,itemName:string}>();

  targetNames = [];
  packetNames = [];
  itemNames = [];
  selectedTargetName:string = '';
  selectedPacketName:string = '';
  selectedItemName:string = '';
  description = '';
  tlm_list_items:GetTlmListItem[] = [];
  tlm_item_list_items:GetTlmItemListItem[] = [];

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
      this.updateItems();
    });
  }

  updateItems() {
    this.api.get_tlm_item_list(this.selectedTargetName, this.selectedPacketName).subscribe(items => {
      this.tlm_item_list_items = items;
      var itemNames = [];
      var arrayLength = items.length;
      for (var i = 0; i < arrayLength; i++) {
        itemNames.push({label: items[i][0], value: items[i][0]})
      }
      this.itemNames = itemNames;
      this.selectedItemName = itemNames[0].value;
      this.description = this.tlm_item_list_items[0][2];
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
        break;
      }
    this.updateItems();
    }
  }

  itemNameChanged(event) {
    var packetNames = [];
    var arrayLength = this.tlm_item_list_items.length;
    for (var i = 0; i < arrayLength; i++) {
      if (event.value === this.tlm_item_list_items[i][0]) {
        this.selectedItemName = this.tlm_item_list_items[i][0];
        this.description = this.tlm_item_list_items[i][2];
        break;
      }
    }
  }

  itemAdded(event) {
    this.onSet.emit({targetName: this.selectedTargetName, packetName:this.selectedPacketName, itemName:this.selectedItemName});
  }

}
