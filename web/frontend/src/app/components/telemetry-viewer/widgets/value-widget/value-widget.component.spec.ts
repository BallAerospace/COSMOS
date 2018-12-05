import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { ValueWidgetComponent } from './value-widget.component';

describe('ValueWidgetComponent', () => {
  let component: ValueWidgetComponent;
  let fixture: ComponentFixture<ValueWidgetComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ ValueWidgetComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(ValueWidgetComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
