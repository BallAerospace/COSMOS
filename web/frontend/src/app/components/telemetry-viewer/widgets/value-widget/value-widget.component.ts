import { Component, OnInit } from '@angular/core';

@Component({
  selector: 'cosmos-value-widget',
  templateUrl: './value-widget.component.html',
  styleUrls: ['./value-widget.component.css']
})
export class ValueWidgetComponent implements OnInit {

  _value:string = "";
  valueclass:string = "cosmos-black";

  constructor() { }

  ngOnInit() {
  }

}
