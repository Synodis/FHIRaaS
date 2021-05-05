import { NgModule } from '@angular/core';
import { Routes, RouterModule } from '@angular/router';
import { EndpointsComponent } from './endpoints/endpoints.component';
import { TenantsComponent } from './tenants/tenants.component';
import { AuthGuard } from './auth/auth.guard';

const routes: Routes = [
  { path: '', redirectTo: '/tenants', pathMatch: 'full',canActivate: [AuthGuard]},
  { path: 'tenants/:id', component: EndpointsComponent },
  { path: 'tenants', component: TenantsComponent },
  { path: 'auth',
  loadChildren: () => import('./auth/auth.module').then(m => m.AuthModule) }
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
