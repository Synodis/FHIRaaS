import { ComponentFixture, TestBed } from '@angular/core/testing';

import { CdaComponent } from './cda.component';

describe('CdaComponent', () => {
  let component: CdaComponent;
  let fixture: ComponentFixture<CdaComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ CdaComponent ]
    })
    .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(CdaComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
