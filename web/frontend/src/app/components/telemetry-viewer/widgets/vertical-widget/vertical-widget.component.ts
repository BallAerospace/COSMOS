import { Component, OnInit, Input } from '@angular/core';
import { WidgetComponent } from "../widget/widget.component";

@Component({
  selector: 'vertical-widget',
  template: `
  <div>
    <div *ngFor="let widget of widgets">
      <dynamic-widget [widget]="widget"></dynamic-widget>
    </div>
    <div style="clear:both;"></div>
  </div>
  `
})
export class VerticalWidgetComponent extends WidgetComponent implements OnInit {
  
  static layout_manager:boolean = true;
  static takes_value:boolean = false;

  widgets:any = [];

  constructor() { super(); }

  ngOnInit() {
  }

  addWidget(widget:any) {
    this.widgets.push(widget);
  }
}
