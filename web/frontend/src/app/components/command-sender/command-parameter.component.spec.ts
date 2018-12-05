import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { CommandParameterComponent } from './command-parameter.component';

describe('CommandParameterComponent', () => {
  let component: CommandParameterComponent;
  let fixture: ComponentFixture<CommandParameterComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ CommandParameterComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(CommandParameterComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should be created', () => {
    expect(component).toBeTruthy();
  });
});
