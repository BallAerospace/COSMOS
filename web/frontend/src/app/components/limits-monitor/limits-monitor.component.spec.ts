import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { LimitsMonitorComponent } from './limits-monitor.component';

describe('LimitsMonitorComponent', () => {
  let component: LimitsMonitorComponent;
  let fixture: ComponentFixture<LimitsMonitorComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ LimitsMonitorComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(LimitsMonitorComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should be created', () => {
    expect(component).toBeTruthy();
  });
});
