import { Component, OnInit, ViewChild, QueryList, ViewChildren, ContentChildren } from '@angular/core';
import { MenuModule, MenuItem, DataListModule, ChartModule, UIChart, SelectItem } from 'primeng/primeng';
import { CosmosApiService, GetTlmPacketItem } from '../../services/cosmos-api.service';
import { CosmosChartComponent } from  '../shared/cosmos-chart/cosmos-chart.component';

@Component({
  selector: 'cosmos-telemetry-grapher',
  templateUrl: './telemetry-grapher.component.html',
  styleUrls: ['./telemetry-grapher.component.css']
})

export class TelemetryGrapherComponent implements OnInit {
  @ViewChildren(CosmosChartComponent) viewCharts: QueryList<CosmosChartComponent>;

  menuItems = [];
  contextMenuItems: MenuItem[];
  selectedItem: any;
  selectedState: string = 'Run';
  stateOptions: SelectItem[];
  //autoCompleteText: string;
  //autoCompleteResults: string[];
  charts: CosmosChartComponent[];
  chartItems: string[] = [];
  activeChartIndex: number;

  constructor(private api: CosmosApiService) {}

  // autoCompleteSearch(event) {
  //   event.query
  //   this.autoCompleteResults = ['ONE','TWO','THREE'];
  // }

  // autoSelect(event) {
  //   console.log(event);
  // }

  buildMenu() {
    var fileMenuItems = {
      label: 'File', items: []
    };
    var graphMenuItems = {
      label: 'Graph', items:
      [
        {label: 'Add Plot', icon: 'fa-plus-circle', command: () => {this.addPlot()} },
      ]
    };

    this.menuItems = [fileMenuItems, graphMenuItems];
  }

  stateChange(event) {
    this.selectedState = event.value;
    this.viewCharts.map(function(chart) {
      chart.setState(event.value);
    });
  }

  private addPlot() {
    this.viewCharts.map(function(chart) {
      chart.setInactive();
    });
    this.charts.push(new CosmosChartComponent());
    this.activeChartIndex = this.charts.length - 1;
    this.chartItems = [];
  }

  ngOnInit() {
    this.activeChartIndex = 0;
    this.charts = [];
    this.charts.push(new CosmosChartComponent());

    this.stateOptions = [];
    this.stateOptions.push({label:'Run', value:'Run'});
    this.stateOptions.push({label:'Pause', value:'Pause'});
    this.stateOptions.push({label:'Stop', value:'Stop'});

    this.buildMenu();
    this.contextMenuItems = [
        {label: 'Delete', icon: 'fa-close', command: (event) => this.deleteItem(this.selectedItem)}
    ];
  }

  clickChart(index, event) {
    this.activeChartIndex = index;
    this.viewCharts.map((chart, i) => {
      if (index == i) {
        this.chartItems = chart.items;
        chart.setActive();
      } else {
        chart.setInactive();
      }
    })
  }

  itemAdded(event) {
    this.viewCharts.map((chart, i) => {
      if (this.activeChartIndex == i) {
        chart.addItem(event.targetName, event.packetName, event.itemName);
        this.chartItems = chart.items;
      }
    })
  }

  deleteItem(item) {
    // var index = this.items.indexOf(item);
    // if (index > -1) {
    //   this.items.splice(index, 1);
    // }
  }
}
