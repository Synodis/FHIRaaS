import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from 'src/environments/environment';

@Injectable({
  providedIn: 'root'
})
export class CdaService {

  constructor(    private http: HttpClient) { }

  import(file,endpointName): any {

    const headers = new HttpHeaders()

    let host = location.host;
    let protocole = location.protocol

    //let base = protocole+'://'+host
    let base = environment.BASE_PATH

    let path = endpointName.replace('fhir/r4','cda')+'/'
 
    var result = this.http.post(base+path, file)
    return result
  }
}
