import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { CommandSenderComponent } from './command-sender.component';

describe('CommandSenderComponent', () => {
  let component: CommandSenderComponent;
  let fixture: ComponentFixture<CommandSenderComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ CommandSenderComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(CommandSenderComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should be created', () => {
    expect(component).toBeTruthy();
  });
});
