import { Component, OnInit } from '@angular/core';
import { Tenant } from '../fhiraas-api/model/tenant';
import { Endpoint } from '../fhiraas-api/model/endpoint';
import { ActivatedRoute } from '@angular/router';
import { DefaultService } from '../fhiraas-api';
import { Location } from '@angular/common';
import { PendingEndpoint } from '../fhiraas-api/model/pendingEndpoint';
@Component({
  selector: 'app-endpoints',
  templateUrl: './endpoints.component.html',
  styleUrls: ['./endpoints.component.scss']
})
export class EndpointsComponent implements OnInit {

  tenant : Tenant;
  endpoints : Endpoint[];
  endpoint : Endpoint;
  pendingEndpoints : PendingEndpoint[];

  constructor(    
    private route: ActivatedRoute,
    private fhiraaService: DefaultService,
    private location: Location) {  }

  ngOnInit(): void {
    this.getTenant();
  }

  goBack(): void {
    this.location.back();
  }

  getTenant(): void {
    const id = this.route.snapshot.paramMap.get('id');
    this.fhiraaService.getTenant(id)
      .subscribe(tenant => this.tenant = tenant);
  }

  addEndpoint(id: string): void {
    id = id.trim();
    if (!id) { return; }
    this.fhiraaService.putEndpoint(this.route.snapshot.paramMap.get('id'),id)
      .subscribe(pendingEndpoint => {
        this.pendingEndpoints.push(pendingEndpoint);
      });
    this.getTenant();
  }
}
