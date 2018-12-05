import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { CosmosValueComponent } from './cosmos-value.component';

describe('CosmosValueComponent', () => {
  let component: CosmosValueComponent;
  let fixture: ComponentFixture<CosmosValueComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ CosmosValueComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(CosmosValueComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should be created', () => {
    expect(component).toBeTruthy();
  });
});
