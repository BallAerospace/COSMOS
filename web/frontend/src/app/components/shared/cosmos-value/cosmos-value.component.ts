import { Component, Input, OnInit } from '@angular/core';

@Component({
  selector: 'cosmos-value',
  templateUrl: './cosmos-value.component.html',
  styleUrls: ['./cosmos-value.component.css']
})
export class CosmosValueComponent implements OnInit {

  private _value = '';
  valueclass = '';

  @Input()
  set value(value: any) {
    if (Object.prototype.toString.call(value).slice(8, -1) === 'Array') {
      var arrayLength = value.length;
      var result = '[';
      for (var i = 0; i < arrayLength; i++) {
        if (Object.prototype.toString.call(value[i]).slice(8, -1) === 'String') {
          result += '"' + value[i] + '"';
        } else {
          result += value[i];
        }
        if (i != (arrayLength - 1)) {
          result += ', ';
        }
      }
      result += ']'
      this._value = result;
    } else if (Object.prototype.toString.call(value).slice(8, -1) === 'Object') {
      this._value = '';
    } else {
      this._value = '' + value;
    }
  }

  @Input()
  set limits_state(limits_state:string) {
    if (limits_state != null) {
      switch(limits_state) {
        case 'GREEN':
        case 'GREEN_HIGH':
          //text << ' (G)' if @colorblind
          this.valueclass = "cosmos-green";
          break;
        case 'GREEN_LOW':
          //text << ' (g)' if @colorblind
          this.valueclass = "cosmos-green";
          break;
        case 'YELLOW':
        case 'YELLOW_HIGH':
          //text << ' (Y)' if @colorblind
          this.valueclass = "cosmos-yellow";
          break;
        case 'YELLOW_LOW':
          //text << ' (y)' if @colorblind
          this.valueclass = "cosmos-yellow";
          break;
        case 'RED':
        case 'RED_HIGH':
          //text << ' (R)' if @colorblind
          this.valueclass = "cosmos-red";
          break;
        case 'RED_LOW':
          //text << ' (r)' if @colorblind
          this.valueclass = "cosmos-red";
          break;
        case 'BLUE':
          //text << ' (B)' if @colorblind
          this.valueclass = "cosmos-blue";
          break;
        case 'STALE':
          //text << ' ($)' if @colorblind
          this.valueclass = "cosmos-purple";
          break;
        default:
          this.valueclass = "cosmos-black";
      }
    } else {
      this.valueclass = '';
    }
  }

  constructor() { }

  ngOnInit() {
  }

}
