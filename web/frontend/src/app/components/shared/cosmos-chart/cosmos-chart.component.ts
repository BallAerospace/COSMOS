import { Input, HostBinding, ViewChild, Component, OnInit, OnDestroy } from '@angular/core';
import { ChartModule, UIChart } from 'primeng/primeng';
import { CosmosApiService, GetTlmListItem } from '../../../services/cosmos-api.service';
import { Observable } from "rxjs/Observable";
import { Subscription } from "rxjs/Subscription";
import "rxjs/add/observable/interval";
import * as ActionCable from 'actioncable';
import * as moment from 'moment';

@Component({
  selector: 'cosmos-chart',
  template: `
    <div [ngClass]="{'active': active, 'inactive': !active }">
      <p-chart #chart type="line" [data]="data" [options]="options"></p-chart>
    </div>
    `,
  styles: [`
    .active {
      border-style: solid;
      border-width: 1px;
      border-color: green;
    }
    .inactive {
      border-style: solid;
      border-width: 1px;
      border-color: white;
    }`]
})

export class CosmosChartComponent implements OnInit, OnDestroy {
  @ViewChild('chart') chart: UIChart;
  data: any = {};
  options: any = {};
  items: any[] = [];
  active: boolean;
  state: string = 'Run';
  cable: ActionCable.Cable;
  subscription: ActionCable.Channel;
  colors = ["blue", "red", "green", "darkorange", "gold", "purple", "hotpink", "lime", "cornflowerblue", "brown", "coral", "crimson", "indigo", "tan", "lightblue", "cyan", "peru"];
  colorIndex = 0;

  constructor() {
    this.data = {
      datasets: []
    }
    this.active = true;
  }

  setActive() {
    this.active = true;
  }

  setInactive() {
    this.active = false;
  }

  setState(state) {
    this.state = state;
  }

  getColor() {
    return this.colors[this.colorIndex++];
  }

  addItem(target, packet, item) {
    var color = this.getColor();
    this.items.push({'item': target + ' ' + packet + ' ' + item});
    this.data.datasets.push({
      label: target+' '+packet+' '+item,
      data: [],
      borderColor: color, // line color
      backgroundColor: color, // point color
    });
    this.subscription.perform("add_item", {item: target+' '+packet+' '+item})
  }

  private received(data: any) {
    if (this.state == 'Stop') {
      return;
    }
    var i = 0;
    while(i < data.length) {
      this.data.datasets[i].data.push({
        x: moment(data[i]['x']).format("YYYY-MM-DD HH:mm:ss"), // ISO 8601 format
        y: data[i]['y'],
      });
      // window.overview.data.datasets[i].data.push({
      //   x: moment(data[i]['x']),
      //   y: data[i]['y'],
      // });
      // TODO: Add the ability to set this point limit
      if (this.data.datasets[i].data.length > 1000) {
        this.data.datasets[i].data.splice(0, this.data.datasets[i].data.length - 1000);
      }
      // TODO: Rather than throwing away overview graph data we should decimate it
      // and display everything
      // if (window.overview.data.datasets[i].data.length > 1000) {
      //   window.overview.data.datasets[i].data.splice(0, window.overview.data.datasets[i].data.length - 1000);
      // }
      i++;
    }
    // TODO: Not calling update while updating the underlying data makes the
    // popups crash with ERROR TypeError: Cannot read property 'skip' of undefined
    // Either need a fix to Chart.js: https://github.com/chartjs/Chart.js/issues/3753
    // or we need to buffer the data during pause and only set the graph data when
    // run resumes.
    if (this.state == 'Run') {
      this.chart.chart.update();
    }
  }

  ngOnInit() {
    this.cable = ActionCable.createConsumer('ws://localhost:3000/cable');
    this.subscription = this.cable.subscriptions.create('PreidentifiedChannel',
      { received: (data) => this.received(data) });

    this.options = {
      //// Container for pan options
      //pan: {
      //  // Boolean to enable panning
      //  enabled: true,
      //  // Panning only in x
      //  mode: 'x'
      //},
      //// Container for zoom options
      //zoom: {
      //  // Boolean to enable zooming
      //  enabled: true,
      //  // Zooming only in x
      //  mode: 'x',
      //},
      elements: {
        line: {
          tension: 0, // disable bezier curves
          fill: false,
        },
      },
      responsive: true,
      animation: false,
      layout: {
        padding: 10,
      },
      scales: {
        xAxes: [{
          type: 'time',
          display: true,
          scaleLabel: {
            display: true,
            labelString: 'Date'
          },
          time: {
            "displayFormats": {
              "millisecond": "h:mm:ss.S",
              "second": "h:mm:ss",
              "minute": "h:mm:ss",
              "hour": "h:mm:ss",
              "day": "MM/DD h:mm:ss",
              "week": "MM/DD h:mm:ss",
              "month": "MM/DD h:mm:ss",
              "quarter": "MM/DD h:mm:ss",
              "year": "YYYY/MM/DD h:mm:ss"
            },
          },
        }],
      }
    }
  }

  ngOnDestroy() {
    this.subscription.unsubscribe();
    this.cable.disconnect();
  }
}
