import { Component, Input, } from '@angular/core';

@Component({
  selector: 'command-parameter-body',
  template: `
    <div *ngIf="value.selected_state == null">
      {{value.val}}
    </div>
    <div *ngIf="value.selected_state != null">
      <div style="float:left;text-align:left;">
        {{value.selected_state_label}}
      </div>
      <div style="float:right">
        {{value.val}}
      </div>
    </div>
  `
})
export class CommandParameterBodyComponent {
  @Input() value;
}
