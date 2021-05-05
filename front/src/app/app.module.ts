import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { TenantsComponent } from './tenants/tenants.component';
import { EndpointsComponent } from './endpoints/endpoints.component';

import { ApiModule } from './fhiraas-api';
import { HttpClientModule } from '@angular/common/http';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { MaterialModule } from './material-module';

import { NgxSpinnerModule } from "ngx-spinner";
import { AddComponent } from './tenants/add/add.component';
import { AddEndpointComponent } from './endpoints/add/add.endpoint.component';
import { AuthGuard } from './auth/auth.guard';
import { AuthInterceptor } from './auth/auth.interceptor';
import { AuthService } from './auth/services/auth.service';
import { AuthModule } from './auth/auth.module';

import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { Hl7Component } from './endpoints/hl7/hl7.component';
import { CdaComponent } from './endpoints/cda/cda.component';
import { FhirComponent } from './endpoints/fhir/fhir.component';

@NgModule({ 
  declarations: [
    AppComponent,
    TenantsComponent,
    EndpointsComponent,
    AddComponent,
    AddEndpointComponent,
    Hl7Component,
    CdaComponent,
    FhirComponent,

  ],
  imports: [
    BrowserModule,  
    // import HttpClientModule after BrowserModule.  
    HttpClientModule,  
    MaterialModule,
    ApiModule,
    AppRoutingModule,
    NgxSpinnerModule,
    BrowserAnimationsModule,
    FormsModule,
    ReactiveFormsModule,    
    AuthModule.forRoot()
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
