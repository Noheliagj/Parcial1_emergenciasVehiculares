import { ComponentFixture, TestBed } from '@angular/core/testing';

import { LoginTecnico } from './login-tecnico.component';

describe('LoginTecnico', () => {
  let component: LoginTecnico;
  let fixture: ComponentFixture<LoginTecnico>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [LoginTecnico],
    }).compileComponents();

    fixture = TestBed.createComponent(LoginTecnico);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
