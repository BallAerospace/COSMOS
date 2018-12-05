import { Component, OnInit, Input, Injector } from '@angular/core';
import { WidgetComponent } from "../widget/widget.component";

@Component({
  selector: 'label-widget',
  template: `{{args[0]}}`
})
export class LabelWidgetComponent extends WidgetComponent implements OnInit {

  static layout_manager:boolean = false;
  static takes_value:boolean = false;

  @Input() args:any = [];

  constructor(private injector: Injector) {
    super();
    this.args = this.injector.get('args');
  }

  ngOnInit() {
  }

}
