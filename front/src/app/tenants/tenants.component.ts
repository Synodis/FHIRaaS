import { Component, OnInit } from '@angular/core';
import { DefaultService, Endpoint } from '../fhiraas-api';
import { Tenant } from '../fhiraas-api/model/tenant';
import { PendingEndpoint } from '../fhiraas-api/model/pendingEndpoint';
import { flatMap } from 'rxjs/operators';
import { interval } from 'rxjs';
import { MatDialog} from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { NgxSpinnerService } from "ngx-spinner"; 
import { AddComponent } from './add/add.component';
import { AddEndpointComponent } from '../endpoints/add/add.endpoint.component';
import { CdaComponent } from '../endpoints/cda/cda.component';
import { Hl7Component } from '../endpoints/hl7/hl7.component';
import { FhirComponent } from '../endpoints/fhir/fhir.component';


@Component({
  selector: 'app-tenants',
  templateUrl: './tenants.component.html',
  styleUrls: ['./tenants.component.scss']
})
export class TenantsComponent implements OnInit {

  tenant : Tenant;
  tenants: Tenant[];
  pendingEndpoints : PendingEndpoint[];
  polling :boolean = false;

  constructor(
    private fhiraaService: DefaultService,
    private spinnerService: NgxSpinnerService,
    public _dialog: MatDialog, 
    private _snackBar: MatSnackBar) {
    this.pendingEndpoints = new Array();
   }

  ngOnInit(): void {
    this.getTenants();
  }

  deleteTenant(tenant : Tenant){
    this.spinnerService.show();  
    this.fhiraaService.deleteTenant(tenant.tenantId).subscribe(        
      res => {
        this.spinnerService.hide();  
        this._snackBar.open(tenant.tenantId+' deleted!','Close', {
          duration: 5000
        });
        console.log(res);
        this.getTenants();
      },
      error => {
        console.log(error);
      });
      this.tenants = this.tenants.filter(obj => obj !== tenant);
  }

  deleteEndpoint(tenant : Tenant,endpoint : Endpoint){
    this.spinnerService.show();
    this.fhiraaService.deleteEndpoint(tenant.tenantId,endpoint.name.split('/').pop()).subscribe(        
      res => {
        this.spinnerService.hide();  
        this._snackBar.open(endpoint.name+' deleted!','Close', {
          duration: 5000
        });
        console.log(res);
        this.getTenants();
      },
      error => {
        console.log(error);
      });
  }
  

  addTenant(id: string): void {
    id = id.trim();
    if (!id) { return; }
    this.spinnerService.show();  
    this.fhiraaService.putTenant(id)
      .subscribe(pendingEndpoint => {
        this.spinnerService.hide();  
        this.pendingEndpoints.push(pendingEndpoint);
        this.getTenants();
        this._snackBar.open(id+' created!','Close', {
          duration: 5000
        });
      },
      error => {
        console.log(error);
      });
  }

  addEndpoint(tenantId: string,endpointId: string): void {
    tenantId = tenantId.trim();
    if (!tenantId) { return; }
    this.spinnerService.show();  
    this.fhiraaService.putEndpoint(tenantId,endpointId)
      .subscribe(pendingEndpoint => {
        this.spinnerService.hide();  
        this.pendingEndpoints.push(pendingEndpoint);
        this.getTenants();
        this._snackBar.open(endpointId+' created!','Close', {
          duration: 5000
        });
      },
      error => {
        console.log(error);
      });
  }

  getTenants(): void {
    this.fhiraaService.getTenants().subscribe(        
      tenants => {
          this.tenants = tenants;
          if (this.pendingEndpoints.length > 0 && !this.polling) {
            this.pollingEndpoints();
          };
          },
          error => {
            console.log(error);
          });

  }

  pollingEndpoints() :void {
    this.polling = true;
    let poll$ = interval(2500)
    .pipe(
        flatMap(() => this.fhiraaService.getTenants())
    )
    .subscribe(        
      tenants => {
          var tPendingEndpoints = 0;
          this.pendingEndpoints = new Array();
          tenants.forEach(tenant => {
            tenant.pendingEndpoints.forEach(pendingEndpoint => {
              this.pendingEndpoints.push(pendingEndpoint);
              tPendingEndpoints = tPendingEndpoints+1;
            });
          });
          if (tPendingEndpoints === 0) {
            this.polling = false;
            poll$.unsubscribe();
            this.tenants = tenants;
          }
          },
          error => {
            console.log(error);
          });

  }

  openAddDialog(): void {
    const dialogRef = this._dialog.open(AddComponent, {
      panelClass: 'modal-panel',
      width: '700px',
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.addTenant(result.tenantId);
      }
    });
  }

  openAddEndpointDialog(tenant:Tenant): void {
    const dialogRef = this._dialog.open(AddEndpointComponent, {
      panelClass: 'modal-panel',
      width: '700px',
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.addEndpoint(tenant.tenantId,result.endpointName);
      }
    });
  }

  openHL7Dialog(endpoint:Endpoint): void {
    const dialogRef = this._dialog.open(Hl7Component, {
      panelClass: 'modal-panel',
      width: '700px',
      data: {
        packages: endpoint
      }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.addTenant(result.tenantId);
      }
    });
  }

  openCDADialog(endpoint:Endpoint): void {
    const dialogRef = this._dialog.open(CdaComponent, {
      panelClass: 'modal-panel',
      width: '700px',
      data: {
        packages: endpoint
      }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.addTenant(result.tenantId);
      }
    });
  }

  openFHIRDialog(endpoint:Endpoint): void {
    const dialogRef = this._dialog.open(FhirComponent, {
      panelClass: 'modal-panel',
      width: '700px',
      data: {
        packages: endpoint
      }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.addTenant(result.tenantId);
      }
    });
  }

}
