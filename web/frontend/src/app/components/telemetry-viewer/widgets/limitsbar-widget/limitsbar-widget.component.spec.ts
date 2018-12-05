import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { LimitsbarWidgetComponent } from './limitsbar-widget.component';

describe('LimitsbarWidgetComponent', () => {
  let component: LimitsbarWidgetComponent;
  let fixture: ComponentFixture<LimitsbarWidgetComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ LimitsbarWidgetComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(LimitsbarWidgetComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
