import { Component, OnInit, Input, Injector } from '@angular/core';
import { WidgetComponent } from "../widget/widget.component";

@Component({
  selector: 'labelvalue-widget',
  template: `<div>{{args[2]}}: {{value}}</div>`
})
export class LabelvalueWidgetComponent extends WidgetComponent implements OnInit {

  static layout_manager:boolean = false;
  static takes_value:boolean = true;

  @Input() args:any = [];

  constructor(private injector: Injector) { 
    super();
    this.args = this.injector.get('args');
  }

  ngOnInit() {
  }

}
