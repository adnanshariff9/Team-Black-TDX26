import { LightningElement, api, track } from 'lwc';
import updateProfile from '@salesforce/apex/OncoAuthController.updateProfile';

export default class OncoProfile extends LightningElement {
    @api initialData; // Passed in from the parent landing page
    @track userData = {};
    successMessage = '';
    errorMessage = '';

    connectedCallback() {
        // Clone the data so we can edit it
        this.userData = { ...this.initialData };
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        this.userData[field] = event.target.value;
        this.successMessage = '';
        this.errorMessage = '';
    }

    handleSave() {
        updateProfile({ 
            firstName: this.userData.firstName, 
            lastName: this.userData.lastName, 
            phone: this.userData.phone 
        })
        .then(result => {
            this.successMessage = result;
        })
        .catch(error => {
            this.errorMessage = error.body ? error.body.message : 'Error updating profile.';
        });
    }
}