import { Component, OnInit, Input, ViewContainerRef, ViewChild } from '@angular/core';

@Component({
  selector: 'dynamic-widget',
  template: `<div #dynamicComponentContainer></div>`
})
export class DynamicWidgetComponent implements OnInit {

  @ViewChild('dynamicComponentContainer', { read: ViewContainerRef }) dynamicComponentContainer: ViewContainerRef;

  constructor() { }

  ngOnInit() {
  }

  @Input() set widget(widget:any) {
    this.dynamicComponentContainer.insert(widget.hostView);
  }

}
