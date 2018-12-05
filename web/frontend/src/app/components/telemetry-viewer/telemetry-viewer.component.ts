import { Component, OnInit } from '@angular/core';

@Component({
  selector: 'cosmos-telemetry-viewer',
  templateUrl: './telemetry-viewer.component.html',
  styleUrls: ['./telemetry-viewer.component.css']
})
export class TelemetryViewerComponent implements OnInit {

  definition:string;

  constructor() { }

  ngOnInit() {
    this.definition = `
      SCREEN AUTO AUTO 1
      HORIZONTAL
        VERTICAL
          LABEL Label1
          LABELVALUE INST HEALTH_STATUS TEMP1
          LABELVALUE INST HEALTH_STATUS TEMP2
          LABELVALUE INST HEALTH_STATUS TEMP3
          LABELVALUE INST HEALTH_STATUS TEMP4
        END
        VERTICAL
          LABEL Label2
          LABELVALUE INST HEALTH_STATUS TEMP1
          LABELVALUE INST HEALTH_STATUS TEMP2
          LABELVALUE INST HEALTH_STATUS TEMP3
          LABELVALUE INST HEALTH_STATUS TEMP4
        END
      END
    `
  }

}
