import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormControl, FormGroup, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';


@Component({
  selector: 'app-add',
  templateUrl: './add.component.html',
  styleUrls: ['./add.component.scss']
})
export class AddComponent implements OnInit {

  tenantForm: FormGroup;

  hide : boolean = true;
  createEndpoint = new FormControl();

  constructor(
  private fb: FormBuilder,
  private dialogRef: MatDialogRef<AddComponent>) {}

  ngOnInit(): void {
    this.createEndpoint.setValue(false);
    this.tenantForm = this.fb.group({
      tenantId: [{value:'', disabled: false}, Validators.required],
      endpointName : [{value:'', disabled: !this.createEndpoint.value},Validators.required],
      endpointPassword : [{value:'', disabled: !this.createEndpoint.value}],
      createEndpoint : this.createEndpoint
    })
  }

  submit() {

    if (this.tenantForm.invalid) {
      return;
    }

    let newTenant: any = {
      tenantId: this.tenantForm.get('tenantId').value,
      createEndpoint : this.tenantForm.get('createEndpoint').value,
      endpointName : this.tenantForm.get('endpointName').value,
      endpointPassword : this.tenantForm.get('endpointPassword').value
    }
    
    this.dialogRef.close(newTenant)
  }

  createEndpointEvent() : void{
    if (this.createEndpoint.value) {
      this.tenantForm.get('endpointName').enable();
      this.tenantForm.get('endpointPassword').enable();
    } else {
      this.tenantForm.get('endpointName').disable();
      this.tenantForm.get('endpointPassword').disable();
    }

  }

}
