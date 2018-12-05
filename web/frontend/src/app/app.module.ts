import {BrowserModule} from '@angular/platform-browser';
import {BrowserAnimationsModule} from '@angular/platform-browser/animations';
import {NgModule} from '@angular/core';
import {FormsModule} from '@angular/forms';
import {DataListModule} from 'primeng/primeng';
import {HttpClientModule} from '@angular/common/http';
import {RouterModule, Routes} from '@angular/router';

import {CosmosApiService} from './services/cosmos-api.service';
import {ConfigParserService} from './services/config-parser.service';

import {ButtonModule,DataTableModule,ContextMenuModule,MenuItem,DropdownModule,PanelModule,SharedModule,MenubarModule,DialogModule,SpinnerModule,ChartModule,SelectButtonModule,AutoCompleteModule,TabViewModule,FieldsetModule} from 'primeng/primeng';
import {AppComponent} from './app.component';
import {CmdTlmServerComponent} from './components/cmd-tlm-server/cmd-tlm-server.component';
import {InterfacesComponent} from './components/cmd-tlm-server/interfaces.component';
import {TargetsComponent} from './components/cmd-tlm-server/targets.component';
import {CmdPacketsComponent} from './components/cmd-tlm-server/cmd-packets.component';
import {TlmPacketsComponent} from './components/cmd-tlm-server/tlm-packets.component';
import {RoutersComponent} from './components/cmd-tlm-server/routers.component';
import {LoggingComponent} from './components/cmd-tlm-server/logging.component';
import {StatusComponent} from './components/cmd-tlm-server/status.component';
import {CommandSenderComponent} from './components/command-sender/command-sender.component';
import {TargetCommandChooserComponent} from './components/command-sender/target-command-chooser.component';
import {CommandParameterEditorComponent} from './components/command-sender/command-parameter-editor.component';
import {CommandParameterBodyComponent} from './components/command-sender/command-parameter-body.component';
import {PacketViewerComponent} from './components/packet-viewer/packet-viewer.component';
import {TelemetryGrapherComponent} from './components/telemetry-grapher/telemetry-grapher.component';
import {TargetPacketChooserComponent} from './components/shared/target-packet-chooser/target-packet-chooser.component';
import {TargetPacketItemChooserComponent} from './components/shared/target-packet-item-chooser/target-packet-item-chooser.component';
import {CosmosChartComponent} from './components/shared/cosmos-chart/cosmos-chart.component';
import {CosmosValueComponent} from './components/shared/cosmos-value/cosmos-value.component';
import { LimitsMonitorComponent } from './components/limits-monitor/limits-monitor.component';
import { LimitsEventsComponent } from './components/shared/limits-events/limits-events.component';

//import { ValueWidgetComponent } from './components/shared/value-widget/value-widget.component';
import { LabelvalueWidgetComponent } from './components/telemetry-viewer/widgets/labelvalue-widget/labelvalue-widget.component';
import { LimitsbarWidgetComponent } from './components/telemetry-viewer/widgets/limitsbar-widget/limitsbar-widget.component';
import { LabelWidgetComponent } from './components/telemetry-viewer/widgets/label-widget/label-widget.component';
import { LabelValueLimitsbarWidgetComponent } from './components/telemetry-viewer/widgets/label-value-limitsbar-widget/label-value-limitsbar-widget.component';
import { VerticalWidgetComponent } from './components/telemetry-viewer/widgets/vertical-widget/vertical-widget.component';
import { HorizontalWidgetComponent } from './components/telemetry-viewer/widgets/horizontal-widget/horizontal-widget.component';
import { DynamicWidgetComponent } from './components/telemetry-viewer/widgets/dynamic-widget/dynamic-widget.component';
import { CosmosScreenComponent } from './components/telemetry-viewer/cosmos-screen/cosmos-screen.component';
import { TelemetryViewerComponent } from './components/telemetry-viewer/telemetry-viewer.component';


const appRoutes: Routes = [
  { path: 'cmd-tlm-server', component: CmdTlmServerComponent },
  { path: 'packet-viewer', component: PacketViewerComponent },
  { path: 'telemetry-grapher', component: TelemetryGrapherComponent },
  { path: 'limits-monitor', component: LimitsMonitorComponent },
  { path: 'telemetry-viewer', component: TelemetryViewerComponent },
  { path: 'command-sender', component: CommandSenderComponent },
];

@NgModule({
  declarations: [
    AppComponent,
    CmdTlmServerComponent,
    InterfacesComponent,
    TargetsComponent,
    CmdPacketsComponent,
    TlmPacketsComponent,
    RoutersComponent,
    LoggingComponent,
    StatusComponent,
    CommandSenderComponent,
    CommandParameterEditorComponent,
    CommandParameterBodyComponent,
    PacketViewerComponent,
    TelemetryGrapherComponent,
    TargetCommandChooserComponent,
    TargetPacketChooserComponent,
    TargetPacketItemChooserComponent,
    CosmosChartComponent,
    CosmosValueComponent,
    CosmosValueComponent,
    LimitsMonitorComponent,
    LimitsEventsComponent,
    //ValueWidgetComponent,
    LabelvalueWidgetComponent,
    LimitsbarWidgetComponent,
    LabelWidgetComponent,
    LabelValueLimitsbarWidgetComponent,
    TelemetryViewerComponent,
    CosmosScreenComponent,
    VerticalWidgetComponent,
    HorizontalWidgetComponent,
    DynamicWidgetComponent
  ],
  imports: [
    AutoCompleteModule,
    BrowserModule,
    BrowserAnimationsModule,
    ButtonModule,
    ChartModule,
    SelectButtonModule,
    ContextMenuModule,
    FormsModule,
    TabViewModule,
    FieldsetModule,
    HttpClientModule,
    DataTableModule,
    DropdownModule,
    DataListModule,
    MenubarModule,
    SpinnerModule,
    DialogModule,
    SharedModule,
    PanelModule,
    RouterModule.forRoot(
      appRoutes,
    )
  ],
  providers: [CosmosApiService, ConfigParserService],
  bootstrap: [AppComponent]
})
export class AppModule { }
