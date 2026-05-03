import { LightningElement, track } from 'lwc';
import doLogin from '@salesforce/apex/OncoAuthController.doLogin';
import doRegister from '@salesforce/apex/OncoAuthController.doRegister';
import doForgotPassword from '@salesforce/apex/OncoAuthController.doForgotPassword';

export default class OncoAuth extends LightningElement {
    @track currentView = 'login'; // 'login', 'register', 'forgot'
    @track isLoading = false;
    @track errorMessage = '';
    @track successMessage = '';

    // Form Fields
    email = '';
    password = '';
    firstName = '';
    lastName = '';

    // --- Computed Properties for UI ---
    get isLogin() { return this.currentView === 'login'; }
    get isRegister() { return this.currentView === 'register'; }
    get isForgot() { return this.currentView === 'forgot'; }

    get headerText() {
        if (this.isRegister) return 'Join Onco Global';
        if (this.isForgot) return 'Reset Password';
        return 'Welcome Back';
    }

    get subHeaderText() {
        if (this.isRegister) return 'Create an account to manage your care.';
        if (this.isForgot) return 'Enter your email to receive a reset link.';
        return 'Log in to access your patient portal and schedule appointments.';
    }

    // --- Input Handling ---
    handleInputChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
        this.clearMessages();
    }

    clearMessages() {
        this.errorMessage = '';
        this.successMessage = '';
    }

    // --- View Toggles ---
    toggleRegister() { this.currentView = 'register'; this.clearMessages(); }
    toggleLogin() { this.currentView = 'login'; this.clearMessages(); }
    toggleForgot() { this.currentView = 'forgot'; this.clearMessages(); }

    // --- Actions ---
    handleLogin() {
        if (!this.email || !this.password) {
            this.errorMessage = 'Please enter both email and password.';
            return;
        }
        this.isLoading = true;
        doLogin({ username: this.email, password: this.password })
            .then(url => {
                window.location.href = url; // Redirect to secure portal
            })
            .catch(error => {
                this.errorMessage = error.body ? error.body.message : 'Login failed.';
                this.isLoading = false;
            });
    }

    handleRegister() {
        if (!this.firstName || !this.lastName || !this.email || !this.password) {
            this.errorMessage = 'Please fill out all fields.';
            return;
        }
        this.isLoading = true;
        doRegister({ firstName: this.firstName, lastName: this.lastName, email: this.email, password: this.password })
            .then(url => {
                window.location.href = url;
            })
            .catch(error => {
                this.errorMessage = error.body ? error.body.message : 'Registration failed.';
                this.isLoading = false;
            });
    }

    handleForgot() {
        if (!this.email) {
            this.errorMessage = 'Please enter your email address.';
            return;
        }
        this.isLoading = true;
        doForgotPassword({ username: this.email })
            .then(() => {
                this.successMessage = 'If an account exists, a reset link has been sent.';
                this.isLoading = false;
            })
            .catch(error => {
                this.errorMessage = error.body ? error.body.message : 'Error processing request.';
                this.isLoading = false;
            });
    }
}