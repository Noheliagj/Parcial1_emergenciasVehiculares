import { ComponentFixture, TestBed } from '@angular/core/testing';

import { EmergenciaVista } from './emergencia-vista';

describe('EmergenciaVista', () => {
  let component: EmergenciaVista;
  let fixture: ComponentFixture<EmergenciaVista>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [EmergenciaVista],
    }).compileComponents();

    fixture = TestBed.createComponent(EmergenciaVista);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
