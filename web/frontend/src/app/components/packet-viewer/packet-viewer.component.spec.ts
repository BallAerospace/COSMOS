import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { PacketViewerComponent } from './packet-viewer.component';

describe('PacketViewerComponent', () => {
  let component: PacketViewerComponent;
  let fixture: ComponentFixture<PacketViewerComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ PacketViewerComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(PacketViewerComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should be created', () => {
    expect(component).toBeTruthy();
  });
});
