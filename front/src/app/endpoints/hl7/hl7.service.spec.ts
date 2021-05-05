import { TestBed } from '@angular/core/testing';

import { Hl7Service } from './hl7.service';

describe('Hl7Service', () => {
  let service: Hl7Service;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(Hl7Service);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
