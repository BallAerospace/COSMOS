import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { LimitsEventsComponent } from './limits-events.component';

describe('LimitsEventsComponent', () => {
  let component: LimitsEventsComponent;
  let fixture: ComponentFixture<LimitsEventsComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ LimitsEventsComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(LimitsEventsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
