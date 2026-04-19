import { ComponentFixture, TestBed } from '@angular/core/testing';

import { LoginTaller } from './login-taller';

describe('LoginTaller', () => {
  let component: LoginTaller;
  let fixture: ComponentFixture<LoginTaller>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [LoginTaller],
    }).compileComponents();

    fixture = TestBed.createComponent(LoginTaller);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
