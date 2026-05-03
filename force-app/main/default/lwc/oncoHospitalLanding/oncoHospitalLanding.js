import { LightningElement, track, wire } from 'lwc';
import getUserState from '@salesforce/apex/OncoAuthController.getUserState';

export default class OncoHospitalLanding extends LightningElement {
    @track isGuest = true;
    @track userData = {};
    
    // Modal State Controls
    @track showAuthModal = false;
    @track showProfileModal = false;

    // Fetch user state automatically on page load
    @wire(getUserState)
    wiredUserState({ error, data }) {
        if (data) {
            this.isGuest = data.isGuest;
            this.userData = data;
        } else if (error) {
            console.error('Error fetching user state', error);
        }
    }

    // Modal Toggles
    openAuth() { this.showAuthModal = true; }
    openProfile() { this.showProfileModal = true; }
    closeModals() { 
        this.showAuthModal = false; 
        this.showProfileModal = false; 
    }
    // Handles native Salesforce logout routing
    handleLogout() {
        // Salesforce securely handles session termination at this endpoint
        window.location.replace('/secur/logout.jsp'); 
    }
    
    services = [
        { 
            id: 1, 
            title: 'Pediatric Oncology', 
            icon: 'standard:customers', 
            description: 'Specialized, compassionate cancer care tailored specifically for children and adolescents.' 
        },
        { 
            id: 2, 
            title: 'Medical Oncology', 
            icon: 'standard:custom_component_task', 
            description: 'Advanced chemotherapy, immunotherapy, and cutting-edge targeted therapy treatments.' 
        },
        { 
            id: 3, 
            title: 'Surgical Oncology', 
            icon: 'standard:record', 
            description: 'Minimally invasive and robotic-assisted tumor removal surgeries by expert surgeons.' 
        },
        { 
            id: 4, 
            title: 'Radiation Therapy', 
            icon: 'standard:performance', 
            description: 'State-of-the-art precision radiation treatments to target tumors accurately.' 
        }
    ];
}