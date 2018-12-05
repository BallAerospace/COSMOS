import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { LabelValueLimitsbarWidgetComponent } from './label-value-limitsbar-widget.component';

describe('LabelValueLimitsbarWidgetComponent', () => {
  let component: LabelValueLimitsbarWidgetComponent;
  let fixture: ComponentFixture<LabelValueLimitsbarWidgetComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ LabelValueLimitsbarWidgetComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(LabelValueLimitsbarWidgetComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
