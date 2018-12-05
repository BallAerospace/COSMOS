import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { TargetPacketItemChooserComponent } from './target-packet-item-chooser.component';

describe('TargetPacketItemChooserComponent', () => {
  let component: TargetPacketItemChooserComponent;
  let fixture: ComponentFixture<TargetPacketItemChooserComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ TargetPacketItemChooserComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(TargetPacketItemChooserComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should be created', () => {
    expect(component).toBeTruthy();
  });
});
