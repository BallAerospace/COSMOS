import { Component, EventEmitter, Input, Output, forwardRef } from '@angular/core';
import {NG_VALUE_ACCESSOR, ControlValueAccessor} from '@angular/forms';

export const COMMAND_PARAM_VALUE_ACCESSOR: any = {
  provide: NG_VALUE_ACCESSOR,
  useExisting: forwardRef(() => CommandParameterEditorComponent),
  multi: true
};

export interface CmdParamValAndStates {
  val: any;
  states: any;
  selected_state: any;
  selected_state_label: string;
  manual_value: any;
}

export interface CmdParam {
  parameter_name;
  val_and_states: CmdParamValAndStates;
  description;
  units;
  type;
}

@Component({
  selector: 'command-parameter-editor',
  template: `
    <input #box *ngIf="states == null" type="text"
      [value]="value.val"
      (focus)="onFocus($event)"
      (blur)="onBlur($event)"
      (change)="handleChange($event, box.value)">
    <div *ngIf="states != null" style="float:left;width:100%;">
      <p-dropdown #dd
        [(ngModel)]="value.selected_state"
        [options]="states"
        [autoWidth]="false"
        [style]="{'width':'70%', 'float':'left'}"
        (onFocus)="onFocus($event)"
        (onBlur)="onBlur($event)"
        (onChange)="handleStateChange($event, dd.selectedOption)"
        appendTo="body">
      </p-dropdown>
      <input #manual
        [value]="value.val"
        style="float:left;width:29%;"
        (change)="handleChange($event, manual.value)">
    </div>
  `,
  providers: [COMMAND_PARAM_VALUE_ACCESSOR]
})
export class CommandParameterEditorComponent implements ControlValueAccessor {

  @Input() value: CmdParamValAndStates = {val: '', states: null, selected_state: null, selected_state_label: '', manual_value: null};
  @Output() onChange: EventEmitter<any> = new EventEmitter();
  onChangeCallback: Function = () => {};
  onTouchedCallback: Function = () => {};
  focused: boolean = false;
  states: any = null;

  onFocus(event) {
    this.focused = true;
  }

  onBlur(event) {
    this.focused = false;
    this.onTouchedCallback();
  }

  handleChange(event, value) {
    this.value.val = value;
    this.value.manual_value = value;
    if (this.value.states) {
      var selected_state = "MANUALLY ENTERED";
      var selected_state_label = "MANUALLY_ENTERED";
      for (var key in this.value.states) {
        if (this.value.states.hasOwnProperty(key)) {
          if (value == this.value.states[key]) {
            selected_state_label = key;
            selected_state = value;
            break;
          }
        }
      }
      this.value.selected_state = selected_state;
      this.value.selected_state_label = selected_state_label;
    }
    else {
      this.value.selected_state = null;
    }
    this.onChangeCallback(this.value);
    this.onChange.emit(this.value);
  }

  handleStateChange(event, state) {
    this.value.selected_state_label = state.label;
    if (state.label == "MANUALLY ENTERED") {
      this.value.val = this.value.manual_value;
      // Stop propagation of the click event so the editor stays active
      // to let the operator enter a manual value.
      event.originalEvent.stopPropagation();
    }
    else {
      this.value.val = state.value;
      this.onChangeCallback(this.value);
      this.onChange.emit(this.value);
    }
  }

  writeValue(value: any): void {
    if (value) {
      this.value = value;

      if (value.states != null)
      {
        this.states = [];
        for (var key in value.states) {
          if (value.states.hasOwnProperty(key)) {
            this.states.push({label: key, value: value.states[key]});
          }
        }

        this.states.push({label: "MANUALLY ENTERED", value: "MANUALLY ENTERED"});

        // TBD pick default better (use actual default instead of just first item in list)
        this.value.selected_state = this.states[0].value;
        this.value.selected_state_label = this.states[0].label;
      }
      else {
        this.states = null;
      }
    }
  }

  registerOnChange(fn: Function): void {
    this.onChangeCallback = fn;
  }

  registerOnTouched(fn: Function): void {
    this.onTouchedCallback = fn;
  }
}

