import { ComponentFixture, TestBed } from '@angular/core/testing';

import { FhirComponent } from './fhir.component';

describe('FhirComponent', () => {
  let component: FhirComponent;
  let fixture: ComponentFixture<FhirComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ FhirComponent ]
    })
    .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(FhirComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
