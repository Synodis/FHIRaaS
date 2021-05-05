import { ComponentFixture, TestBed } from '@angular/core/testing';

import { Hl7Component } from './hl7.component';

describe('Hl7Component', () => {
  let component: Hl7Component;
  let fixture: ComponentFixture<Hl7Component>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ Hl7Component ]
    })
    .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(Hl7Component);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
