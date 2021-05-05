import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormControl, FormGroup, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';


@Component({
  selector: 'app-add',
  templateUrl: './add.endpoint.component.html',
  styleUrls: ['./add.endpoint.component.scss']
})
export class AddEndpointComponent implements OnInit {

  endpointForm: FormGroup;

  hide : boolean = true;

  constructor(
  private fb: FormBuilder,
  private dialogRef: MatDialogRef<AddEndpointComponent>) {}

  ngOnInit(): void {
    this.endpointForm = this.fb.group({
      endpointName : [],
      endpointPassword : [],
    })
  }

  submit() {

    if (this.endpointForm.invalid) {
      return;
    }

    let newTenant: any = {
      endpointName : this.endpointForm.get('endpointName').value,
      endpointPassword : this.endpointForm.get('endpointPassword').value
    }
    
    this.dialogRef.close(newTenant)
  }
  

}
