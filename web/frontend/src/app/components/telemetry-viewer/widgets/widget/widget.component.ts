import { Component, OnInit } from '@angular/core';

@Component({
  selector: 'widget',
  template: `<div></div>`
})
export class WidgetComponent implements OnInit {

  screen = null;
  polling_period = null;
  value_type = "WITH_UNITS";
  value = null;
  limits_set = "DEFAULT";
  limits_state = null;
  
  constructor() { }

  ngOnInit() {
  }

  update_widget() { }

  setValueAndLimitsState(value, limits_state) {
    this.limits_state = limits_state;
    this.value = value;
  }
}
