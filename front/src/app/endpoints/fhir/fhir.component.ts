import { Component, Inject, OnInit } from '@angular/core';
import { FhirClient } from 'ng-fhir/FhirClient';
import { MAT_DIALOG_DATA } from '@angular/material/dialog';
import { Endpoint } from 'src/app/fhiraas-api';
import { MatTableDataSource } from '@angular/material/table';
import { ReactiveFormsModule, FormControl } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';

@Component({
  selector: 'app-fhir',
  templateUrl: './fhir.component.html',
  styleUrls: ['./fhir.component.scss']
})
export class FhirComponent implements OnInit {

  private fhirHttpService: FhirClient
  private endpoint : Endpoint;

  searched = false;
  bundle: fhir.r4.Bundle;
  dataSource = new MatTableDataSource<fhir.r4.BundleEntry>();
  

  public searchName: FormControl;
  public searchNameValue = '';

  selectedPatient: fhir.r4.Patient;

  constructor(@Inject(MAT_DIALOG_DATA) public data: any) { 

    this.endpoint = data.packages;
    var config = {
      'baseUrl': location.protocol+this.endpoint.name,
      'credentials': 'same-origin',
    };
    this.fhirHttpService = new FhirClient(config);

    this.searchName = new FormControl();
    this.searchName.valueChanges
      .pipe(
        debounceTime(400),
        distinctUntilChanged()
      )
      .subscribe(term => {
        console.log('called with ' + term);

        this.fhirHttpService.search({type: 'Patient', query: {name : term}}).then((response) => {
          if(response.data){
            this.setBundle(response.data);
          }
        }, (err) => {
          console.log(err);
        });
      });
      this.fhirHttpService.search({type: 'Patient', query: {}}).then((response) => {
        if(response.data){
          this.setBundle(response.data);
        }
      }, (err) => {
        console.log(err);
      });
  }

  getPatientFamilyName(entry: fhir.r4.BundleEntry): string {
    const patient = <fhir.r4.Patient>entry.resource;
    if (patient.name && patient.name.length > 0 && patient.name[0].family) {
      return patient.name[0].family;
    }
    return '';
  }

  getPatientGivenNames(entry: fhir.r4.BundleEntry): string {
    const patient = <fhir.r4.Patient>entry.resource;
    if (patient.name && patient.name.length > 0 && patient.name[0].given) {
      return (<fhir.r4.Patient>entry.resource).name[0].given.join(' ');
    }
    return '';
  }

  getPatientBirthDate(entry: fhir.r4.BundleEntry): string {
    const patient = <fhir.r4.Patient>entry.resource;
    if (patient.birthDate) {
      return patient.birthDate;
    }
    return '';
  }

  getPatientAddressLines(entry: fhir.r4.BundleEntry): string {
    const patient = <fhir.r4.Patient>entry.resource;
    if (
      patient.address &&
      patient.address.length > 0 &&
      patient.address[0].line
    ) {
      return patient.address[0].line.join(', ');
    }
    return '';
  }

  getPatientAddressCity(entry: fhir.r4.BundleEntry): string {
    const patient = <fhir.r4.Patient>entry.resource;
    if (
      patient.address &&
      patient.address.length > 0 &&
      patient.address[0].city
    ) {
      return patient.address[0].city;
    }
    return '';
  }

  selectRow(row: fhir.r4.BundleEntry) {
    const selection = row.resource;
    const readObj = { type: 'Patient', id: selection.id };
    this.fhirHttpService.read(readObj).then(response => {
      this.selectedPatient = response.data;
    });
  }

  setBundle(bundle: fhir.r4.Bundle) {
    this.bundle = <fhir.r4.Bundle>bundle;
    this.dataSource.data = this.bundle.entry;
    this.selectedPatient = undefined;
  }

  ngOnInit() {}
}
