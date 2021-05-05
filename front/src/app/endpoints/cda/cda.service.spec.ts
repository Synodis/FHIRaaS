import { TestBed } from '@angular/core/testing';

import { CdaService } from './cda.service';

describe('CsaService', () => {
  let service: CdaService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(CdaService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
