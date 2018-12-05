import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { TelemetryViewerComponent } from './telemetry-viewer.component';

describe('TelemetryViewerComponent', () => {
  let component: TelemetryViewerComponent;
  let fixture: ComponentFixture<TelemetryViewerComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ TelemetryViewerComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(TelemetryViewerComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
