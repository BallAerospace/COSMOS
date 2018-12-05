import { Component, Input, OnInit } from '@angular/core';

@Component({
  selector: 'limits-events',
  templateUrl: './limits-events.component.html',
  styleUrls: ['./limits-events.component.css']
})
export class LimitsEventsComponent implements OnInit {

  private _eventMessages:any[];

  @Input()
  set eventMessages(eventMessages: any) {
    this._eventMessages = eventMessages;
  }

  constructor() { }

  ngOnInit() {
  }

}
