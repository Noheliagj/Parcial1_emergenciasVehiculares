import { ComponentFixture, TestBed } from '@angular/core/testing';

import { RegistroTallerComponent } from './registro-taller';

describe('RegistroTaller', () => {
  let component: RegistroTallerComponent;
  let fixture: ComponentFixture<RegistroTallerComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [RegistroTallerComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(RegistroTallerComponent);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
