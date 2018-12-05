import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { TargetPacketChooserComponent } from './target-packet-chooser.component';

describe('TargetPacketChooserComponent', () => {
  let component: TargetPacketChooserComponent;
  let fixture: ComponentFixture<TargetPacketChooserComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ TargetPacketChooserComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(TargetPacketChooserComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should be created', () => {
    expect(component).toBeTruthy();
  });
});
