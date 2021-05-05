import { Component, OnInit } from '@angular/core';
import { FormGroup, Validators, FormBuilder } from '@angular/forms';
import { AuthService } from '../services/auth.service';
import { tap } from 'rxjs/operators';
import { ActivatedRoute, Router } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';

@Component({
  selector: 'app-login',
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.scss']
})
export class LoginComponent implements OnInit {

  form: FormGroup;
  loading: boolean;
  returnUrl: string;

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private fb: FormBuilder,
    private authService: AuthService,
    private _snackBar: MatSnackBar, 
  ) { }

  ngOnInit() {
    this.returnUrl = this.route.snapshot.queryParams['returnUrl'] || '/';

    const formControls = {
      username: ['', Validators.required],
      password: ['', Validators.required]
    };
    this.form = this.fb.group(formControls);
  }

  onLogin() {
    let data = { ...this.form.value }
    const username = data.username;
    const password = data.password;
    
    this.loading = true;
    this.authService.login(username, password).subscribe(
      data => { 
        this.loading = false;
        // after login, redirect to returnUrl
        this.router.navigateByUrl(this.returnUrl);
      },
      error => {
        this.loading = false;
        this._snackBar.open('[Login] Wrong username or password','Close', {
          duration: 5000
        });
      }
    );
    
  }

}
