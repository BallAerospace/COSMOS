import { Component, Input, OnInit, ReflectiveInjector, ComponentFactoryResolver, ViewChild } from '@angular/core';
import { CosmosApiService } from '../../../services/cosmos-api.service';
import { ConfigParserService } from '../../../services/config-parser.service';
import { LabelWidgetComponent } from '../widgets/label-widget/label-widget.component'
import { LabelvalueWidgetComponent } from '../widgets/labelvalue-widget/labelvalue-widget.component'
import { VerticalWidgetComponent } from '../widgets/vertical-widget/vertical-widget.component'
import { HorizontalWidgetComponent } from '../widgets/horizontal-widget/horizontal-widget.component'
import { Observable } from "rxjs/Observable";
import { Subscription } from "rxjs/Subscription";
import "rxjs/add/observable/interval";

class Widgets {
  items = [];
  value_types = [];
  item_widgets = [];
  non_item_widgets = [];
  invalid_messages = [];
  named_widgets = {};
  polling_period = null;
  updater:Subscription = null;
  values = [];
  limits_states = [];
  limits_settings = [];
  limits_set = "DEFAULT";
  current_limits_set = "DEFAULT";

  constructor(private api: CosmosApiService) { }

  add_widget(klass, parameters, widget, widget_name, substitute, original_target_name, force_substitute) {
    if (klass.takes_value) {
      if ((substitute) && ((original_target_name === parameters[0].toUpperCase()) || (force_substitute))) {
        this.items.push([substitute, parameters[1], parameters[2]]);
      } else {
        this.items.push([parameters[0], parameters[1], parameters[2]]);
      }
      this.value_types.push(widget.value_type);
      this.item_widgets.push(widget);
    } else {
      this.non_item_widgets.push(widget);
    }

    if (widget_name) {
      this.named_widgets[widget_name] = widget;
    }
  }

  update() {
    if (!(this.item_widgets.length === 0)) {
      this.api.get_tlm_values(this.items, this.value_types).subscribe((data) => {
        // TODO: Support limits ranges changes
        // index = 0
        // @items.each do |target_name, packet_name, item_name|
        //  begin
        //    System.limits.set(target_name, packet_name, item_name, limits_settings[index][0], limits_settings[index][1], limits_settings[index][2], limits_settings[index][3], limits_settings[index][4], limits_settings[index][5], limits_set) if limits_settings[index]
        //  rescue
        //    # This can fail if we missed setting the DEFAULT limits set earlier - Oh well
        //  end
        //  index += 1
        //end
        this.values = data[0];
        this.limits_states = data[1];
        this.limits_settings = data[2];
        this.limits_set = data[3];
        this.update_gui();
      });
    } else {
      this.update_gui();
    }    
  }

  start_updates() {
    this.update();
    let refreshInterval = this.polling_period * 1000;
    this.updater = Observable.interval(refreshInterval).subscribe(x => {
      this.update();
    });
  }

  stop_updates() {
    if (this.updater != null) { this.updater.unsubscribe(); this.updater = null; }
  }

  update_limits_set() {
    if (this.limits_set !== this.current_limits_set) {
      this.current_limits_set = this.limits_set;
      for (let i = 0; i < this.item_widgets.length; i++) {
        this.item_widgets[i].limits_set = this.current_limits_set;
      }
    }
  }

  update_gui() {
    if (!(this.item_widgets.length === 0)) {
      // Handle change in limits set☺
      this.update_limits_set();

      // Update widgets with values and limits_states
      for (let i = 0; i < this.item_widgets.length; i++) {
        this.item_widgets[i].setValueAndLimitsState(this.values[i], this.limits_states[i]);
      }
    }

    // Update non_item widgets
    for (let i = 0; i < this.non_item_widgets.length; i++) {
      this.non_item_widgets[i].update_widget();
    }
  }
}

@Component({
  selector: 'cosmos-screen',
  entryComponents: [HorizontalWidgetComponent, LabelWidgetComponent, LabelvalueWidgetComponent, VerticalWidgetComponent],
  template: `
  <div style="margin:10px;">
    <p-panel header="Title">
      <vertical-widget #mainVerticalWidget></vertical-widget>
    </p-panel>
  </div>
  `
})
export class CosmosScreenComponent implements OnInit {

  @ViewChild('mainVerticalWidget')
  set mainVerticalWidget(component) {
    this.layout_stack = [component];
  }

  widgetToComponentMapping = {
    'HORIZONTAL' : HorizontalWidgetComponent,
    'LABEL': LabelWidgetComponent,
    'LABELVALUE': LabelvalueWidgetComponent,
    'VERTICAL' : VerticalWidgetComponent,
  }

  widgets = null;
  current_widget = null;
  layout_stack = [];
  componentData:any;
  _definition:string;
  width:number;
  height:number;
  fixed:boolean;
  global_settings = {};
  global_subsettings = {};
  substitute = false;
  original_target_name = null;
  force_substitute = false;

  constructor(private config_parser: ConfigParserService, private resolver: ComponentFactoryResolver, private api: CosmosApiService) {
    this.widgets = new Widgets(api);
  }

  ngOnInit() {
  }

  create_widget(componentType, parameters) {
    // Inputs need to be in the following format to be resolved properly
    let inputProviders = ['args'].map((inputName) => {return {provide: inputName, useValue: parameters};});
    let resolvedInputs = ReflectiveInjector.resolve(inputProviders);

    // We create an injector out of the data we want to pass down and this components injector
    let injector = ReflectiveInjector.fromResolvedProviders(resolvedInputs);

    // We create a factory out of the component we want to create
    let factory = this.resolver.resolveComponentFactory(componentType);

    // We create the component using the factory and the injector
    let widget = factory.create(injector);

    return widget;
  }

  process_widget(keyword, parameters) {
    var widget_name = null;
    if (keyword === 'NAMED_WIDGET') {
      this.config_parser.verify_num_parameters(2, null, `${keyword} <Widget Name> <Widget Type> <Widget Settings... (optional)>`);
      widget_name = parameters[0].toUpperCase();
      keyword = parameters[1].toUpperCase();
      parameters = parameters.slice(2, parameters.length);
    } else {
      this.config_parser.verify_num_parameters(0, null, `${keyword} <Widget Settings... (optional)>`);
    }

    // Turn keyword into componentType
    var componentType = this.widgetToComponentMapping[keyword];
    var widget =  null;
    var widgetRef = null;
    if (componentType) {
      if (componentType.takes_value) {
        this.config_parser.verify_num_parameters(3, null, `${keyword} <Target Name> <Packet Name> <Item Name> <Widget Settings... (optional)>`);
        try {
          if ((this.substitute) && ((this.original_target_name === parameters[0].toUpperCase()) || (this.force_substitute))) {
            // System.telemetry.packet_and_item(@substitute, parameters[1], parameters[2])
            // TODO: Implement item existence check
            var substitute_parameters = parameters.slice();
            substitute_parameters[0] = this.substitute;
            widgetRef = this.create_widget(componentType, substitute_parameters);
          } else {
            // System.telemetry.packet_and_item(*parameters[0..2])
            // TODO: Implement item existence check
            widgetRef = this.create_widget(componentType, parameters);
          }
        } catch(e) {
          this.widgets.invalid_messages.push(`${this.config_parser.line_number}: ${parameters.join(" ").trim()}`);
          return null;
        }
      } else {
        widgetRef = this.create_widget(componentType, parameters);
      }
      widget = widgetRef.instance;

      var current_layout = this.layout_stack[this.layout_stack.length - 1];
      current_layout.addWidget(widgetRef);

      // Add to Layout Stack if Necessary
      if (componentType.layout_manager) {
        this.layout_stack.push(widget);
      }

      // Assign screen
      widget.screen = this;

      // Assign polling period
      if (this.widgets.polling_period) {
        widget.polling_period = this.widgets.polling_period;
      } else {
        throw "SCREEN keyword must appear before any widgets";
      }

      // # Apply Global Settings
      // global_settings.each do |global_klass, settings|
      //   if widget.class == global_klass
      //     settings.each do |setting|
      //       if setting.length > 1
      //         widget.set_setting(setting[0], setting[1..-1])
      //       else
      //         widget.set_setting(setting[0], [])
      //       end
      //     end
      //   end
      // end

      // # Apply Global Subsettings
      // global_subsettings.each do |global_klass, settings|
      //   if widget.class == global_klass
      //     settings.each do |setting|
      //       widget_index = setting[0]
      //       if setting.length > 2
      //         widget.set_subsetting(widget_index, setting[1], setting[2..-1])
      //       else
      //         widget.set_subsetting(widget_index, setting[1], [])
      //       end
      //     end
      //   end
      // end

      this.widgets.add_widget(componentType, parameters, widget, widget_name, this.substitute, this.original_target_name, this.force_substitute);

    } else {
      console.log("Ignoring unknown widget: " + keyword);
    }

    return widget;
  }

  @Input()
  set definition(definition: string) {
    this.componentData = {component: LabelvalueWidgetComponent, args: ['INST', 'HEALTH_STATUS', 'TEMP1']};

    this.current_widget = this.layout_stack[0];

    this._definition = definition;
    var self = this;
    this.config_parser.parse_string(this._definition, "", false, true, function(keyword, parameters) {
      if (keyword) {
        switch (keyword) {
          case 'SCREEN':
            self.config_parser.verify_num_parameters(3, 4, `${keyword} <Width or AUTO> <Height or AUTO> <Polling Period> <FIXED>`);
            self.width = parseInt(parameters[0]);
            self.height = parseInt(parameters[1]);
            self.widgets.polling_period = parseFloat(parameters[2]);
            if (parameters.length === 4) {
              self.fixed = true;
            } else {
              self.fixed = false;
            }
            break;
          case 'END':
            self.config_parser.verify_num_parameters(0, 0, `${keyword}`);
            self.current_widget = self.layout_stack.pop();
            // Call the complete method to allow layout widgets to do things
            // once all their children have been added
            // Need the respond_to? to protect against the top level widget
            // added by the SCREEN code above. It adds a Qt::VBoxLayout
            // to the stack and that class doesn't have a complete method.
            //current_widget.complete();
            break;
          case 'SETTING':
            self.config_parser.verify_num_parameters(1, null, `${keyword} <Setting Name> <Setting Values... (optional)>`);
            if (parameters.length > 1) {
              self.current_widget.set_setting(parameters[0], parameters.slice(1, parameters.length));
            } else {
              self.current_widget.set_setting(parameters[0], []);
            }
            break;
          case 'SUBSETTING':
            self.config_parser.verify_num_parameters(2, null, `${keyword} <Widget Index (0..?)> <Setting Name> <Setting Values... (optional)>`);
            if (parameters.length > 2) {
              self.current_widget.set_subsetting(parameters[0], parameters[1], parameters.slice(2, parameters.length));
            } else {
              self.current_widget.set_subsetting(parameters[0], parameters[1], []);
            }
            break;
          case 'GLOBAL_SETTING':
            self.config_parser.verify_num_parameters(2, null, `${keyword} <Widget Type> <Setting Name> <Setting Values... (optional)>`);
            //klass = Cosmos.require_class(parameters[0].to_s.downcase + '_widget');
            //global_settings[klass] ||= [];
            //global_settings[klass] << parameters[1..-1];
            break;
          case 'GLOBAL_SUBSETTING':
            self.config_parser.verify_num_parameters(3, null, `${keyword} <Widget Type> <Widget Index (0..?)> <Setting Name> <Setting Values... (optional)>`);
            //klass = Cosmos.require_class(parameters[0].to_s.downcase + '_widget');
            //global_subsettings[klass] ||= [];
            //global_subsettings[klass] << [parameters[1]].concat(parameters[2..-1]);
            break;
          default:
            self.current_widget = self.process_widget(keyword, parameters);
            break;
        } // switch keyword
      } // if keyword
    });

    self.widgets.start_updates();
  }

  ngOnDestroy() {
    this.widgets.stop_updates();
  }

}
