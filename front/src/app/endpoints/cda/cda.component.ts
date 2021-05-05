import { Component, ElementRef, Inject, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from "@angular/forms";
import { MatSnackBar } from '@angular/material/snack-bar';
import { CdaService } from './cda.service'
import { MAT_DIALOG_DATA } from '@angular/material/dialog';
import { Endpoint } from 'src/app/fhiraas-api';
import { NgxSpinnerService } from "ngx-spinner"; 
import { environment } from 'src/environments/environment';

@Component({
  selector: 'app-cda',
  templateUrl: '../upload.component.html',
  styleUrls: ['../upload.component.scss']
})
export class CdaComponent implements OnInit {

  title = 'CDA';
  form: FormGroup;
  submitted = false;
  file: any;
  endpoint : Endpoint;

  constructor(@Inject(MAT_DIALOG_DATA) public data: any,
    public fb: FormBuilder,
    private spinnerService: NgxSpinnerService,
    private _snackBar: MatSnackBar,
    private cdaService : CdaService
  ) {
    this.endpoint = data.packages;
    this.form = this.fb.group({

      file: [null],

    })
  }

  ngOnInit() { }

  onDrop(event){
    this.uploadFile(event[0])
  }

  fromBrowser(event){
    this.uploadFile(event.target.files[0])
  }

  uploadFile(file) {
    this.form.patchValue({
      file: file
    });
    this.form.get('file').updateValueAndValidity()
    this.file = file
    var reader = new FileReader();
    var SLICE = 1024 * 1;
    var blob = file.slice(0, file.size < SLICE ? file.size : SLICE );
    reader.onload = (e) => {
      var input: HTMLInputElement = <HTMLInputElement>document.getElementById('filePreview')
      input.value = reader.result.toString();
    }
    reader.readAsText(blob);
  }

  reset() {
    this.submitted = false;
    this.form.reset();
    this.file = null;
  }

  /**
   * Delete file 
  */
  deleteFile() {
    this.file = null;
  }

  /**
   * format bytes
   * @param bytes (File size in bytes)
   * @param decimals (Decimals point)
   */
  formatBytes(bytes, decimals) {
    if (bytes === 0) {
      return '0 Bytes';
    }
    const k = 1024;
    const dm = decimals <= 0 ? 0 : decimals || 2;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
  }

  submitForm() {

    this.submitted = true;

    
      if (this.file == null){
        let that = this;
        this._snackBar.open("File is mandatory",'Close', {
          duration: 5000
        });
        return;
      }
    if (this.form.invalid) {
      return;
    }

    this.spinnerService.show(); 
    this.file = this.form.get('file').value
    let name = this.endpoint.name
    this.cdaService.import(this.file,name).subscribe((data: any) => {
      this.spinnerService.hide(); 
      this._snackBar.open('File sent!', 'View Trace', { duration: 10000})
      .onAction()
      .subscribe(() =>  
        ///v1/fhiraas/synodis/fhir/r4/endpoint 
        this.window_open(environment.BASE_PATH+'/csp/healthshare/'+name.split('/')[3]+'/EnsPortal.MessageViewer.zen')
    
      );
      this.reset()

  }, error => {
      this.spinnerService.hide(); 
      console.log("There was an error importing file", error);

      this._snackBar.open("Failed : "+error.message,'Close', {
        duration: null
      });

  })
  }

    // Open a window with the given URL
    window_open(url: any) {
      var winReference = window.open();
      winReference.location = url;
      winReference.parent.focus();
    }

  // convenience getter for easy access to form fields
  get f() { return this.form.controls; }

}

