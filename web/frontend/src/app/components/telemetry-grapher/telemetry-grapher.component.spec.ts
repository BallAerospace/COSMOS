import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { TelemetryGrapherComponent } from './telemetry-grapher.component';

describe('PacketViewerComponent', () => {
  let component: TelemetryGrapherComponent;
  let fixture: ComponentFixture<TelemetryGrapherComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ TelemetryGrapherComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(TelemetryGrapherComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should be created', () => {
    expect(component).toBeTruthy();
  });
});
