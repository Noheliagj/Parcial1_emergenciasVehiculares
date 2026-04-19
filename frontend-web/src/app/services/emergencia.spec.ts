import { TestBed } from '@angular/core/testing';

import { Emergencia } from './emergencia';

describe('Emergencia', () => {
  let service: Emergencia;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(Emergencia);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
