import { LightningElement, api } from 'lwc';
import getCompatibility from '@salesforce/apex/OncoSchedulerBase.getCompatibility';

export default class OncoAgentResponseRenderer extends LightningElement {
    @api value;
    @api status;
    @api title;
    @api message;
    @api payloadJson;
    @api nextAction;
    copiedMessage = '';
    copiedKey = '';
    selectedClinicId = '';
    selectedDepartmentId = '';
    validDepartmentIds = [];
    validDoctorIds = [];
    scopedDoctors = [];

    get normalized() {
        return this.value || {
            status: this.status,
            title: this.title,
            message: this.message,
            dataJson: this.payloadJson,
            nextAction: this.nextAction
        };
    }

    get payload() {
        const raw = this.normalized?.payloadJson || this.normalized?.dataJson;
        if (!raw) {
            return {};
        }
        try {
            return JSON.parse(raw);
        } catch (e) {
            return {};
        }
    }

    get displayTitle() {
        return this.normalized?.title || 'Onco Global';
    }

    get displayMessage() {
        return this.normalized?.message || '';
    }

    get displayNextAction() {
        return this.normalized?.nextAction || '';
    }

    get cardClass() {
        const state = (this.normalized?.status || '').toLowerCase();
        return `response-card ${state}`;
    }

    get iconName() {
        const state = (this.normalized?.status || '').toLowerCase();
        if (state === 'success') {
            return 'utility:success';
        }
        if (state === 'error') {
            return 'utility:error';
        }
        if (state === 'noresults') {
            return 'utility:search';
        }
        return 'utility:info';
    }

    get clinics() {
        return this.payload.clinics || [];
    }

    get clinicItems() {
        return this.clinics.map((clinic) => ({
            ...clinic,
            copyKey: `clinic-${clinic.Id}`,
            prompt: `Select ${clinic.Name}${clinic.City ? ` in ${clinic.City}` : ''} as my hospital.`,
            buttonLabel: this.copiedKey === `clinic-${clinic.Id}` ? 'Copied' : 'Select Hospital',
            itemClass: this.selectedClinicId === clinic.Id ? 'result-item selected' : 'result-item'
        }));
    }

    get departments() {
        return this.payload.departments || [];
    }

    get departmentItems() {
        const hasValidation = this.selectedClinicId && this.validDepartmentIds.length > 0;
        return this.departments.map((department) => ({
            ...department,
            copyKey: `department-${department.Id}`,
            prompt: `Select ${department.Name} as my department.`,
            buttonLabel: this.copiedKey === `department-${department.Id}` ? 'Copied' : department.Name,
            buttonClass: this.getSelectableButtonClass(
                `department-${department.Id}`,
                this.selectedDepartmentId === department.Id,
                hasValidation && !this.validDepartmentIds.includes(department.Id)
            ),
            disabled: hasValidation && !this.validDepartmentIds.includes(department.Id)
        }));
    }

    get appointments() {
        return this.payload.appointments || [];
    }

    get appointmentItems() {
        return this.appointments.map((appointment) => ({
            ...appointment,
            rescheduleKey: `reschedule-${appointment.Id}`,
            cancelKey: `cancel-${appointment.Id}`,
            reschedulePrompt: `Reschedule appointment ${appointment.AppointmentNumber || appointment.Id}.`,
            cancelPrompt: `Cancel appointment ${appointment.AppointmentNumber || appointment.Id}.`,
            rescheduleLabel: this.copiedKey === `reschedule-${appointment.Id}` ? 'Copied' : 'Reschedule',
            cancelLabel: this.copiedKey === `cancel-${appointment.Id}` ? 'Copied' : 'Cancel'
        }));
    }

    get doctors() {
        return this.scopedDoctors.length > 0 ? this.scopedDoctors : this.payload.doctors || [];
    }

    get doctorItems() {
        const hasValidation = this.selectedClinicId && this.selectedDepartmentId && this.validDoctorIds.length > 0;
        return this.doctors.map((doctor) => ({
            ...doctor,
            copyKey: `doctor-${doctor.Id}`,
            displayName: this.formatDoctorName(doctor.Name),
            prompt: `Select ${this.formatDoctorName(doctor.Name)} for this appointment.`,
            buttonLabel: this.copiedKey === `doctor-${doctor.Id}` ? 'Copied' : 'Select Doctor',
            disabled: hasValidation && !this.validDoctorIds.includes(doctor.Id),
            itemClass: hasValidation && !this.validDoctorIds.includes(doctor.Id) ? 'result-item disabled' : 'result-item'
        }));
    }

    get slots() {
        return this.payload.slots || [];
    }

    get slotLabels() {
        return this.slots.slice(0, 8).map((slot, index) => {
            const start = slot.startTime || slot.start || slot.StartTime || slot.slotStart || JSON.stringify(slot);
            const end = slot.endTime || slot.end || slot.EndTime || slot.slotEnd || '';
            return {
                key: `${index}-${start}`,
                copyKey: `slot-${index}-${start}`,
                label: this.formatSlot(start, end),
                prompt: `Book ${this.formatSlotPrompt(start, end)}.`,
                buttonLabel: this.copiedKey === `slot-${index}-${start}` ? 'Copied' : this.formatSlot(start, end),
                buttonClass: this.copiedKey === `slot-${index}-${start}` ? 'pill-button copied' : 'pill-button'
            };
        });
    }

    get hasClinics() {
        return this.clinics.length > 0;
    }

    get hasDepartments() {
        return this.departments.length > 0;
    }

    get hasAppointments() {
        return this.appointments.length > 0;
    }

    get hasDoctors() {
        return this.doctors.length > 0;
    }

    get hasSlots() {
        return this.slotLabels.length > 0;
    }

    get showCombinationNotice() {
        return (this.hasClinics && (this.hasDepartments || this.hasDoctors)) || (this.hasDepartments && this.hasDoctors);
    }

    // async handleCopy(event) {
    //     const prompt = event.currentTarget?.dataset?.prompt;
    //     const copyKey = event.currentTarget?.dataset?.copyKey;
    //     const kind = event.currentTarget?.dataset?.kind;
    //     const id = event.currentTarget?.dataset?.id;
    //     if (!prompt) {
    //         return;
    //     }

    //     if (kind === 'clinic') {
    //         this.selectedClinicId = id || '';
    //         this.selectedDepartmentId = '';
    //         await this.loadCompatibility();
    //     } else if (kind === 'department') {
    //         this.selectedDepartmentId = id || '';
    //         await this.loadCompatibility();
    //     }

    //     try {
    //         await navigator.clipboard.writeText(prompt);
    //         this.copiedKey = copyKey || '';
    //         this.copiedMessage = 'Copied. Paste it into the chat when ready.';
    //     } catch (error) {
    //         this.copiedKey = copyKey || '';
    //         this.copiedMessage = prompt;
    //     }
    // }
async handleCopy(event) {
        const prompt = event.currentTarget?.dataset?.prompt;
        const copyKey = event.currentTarget?.dataset?.copyKey;
        const kind = event.currentTarget?.dataset?.kind;
        const id = event.currentTarget?.dataset?.id;
        
        if (!prompt) return;

        let textToCopy = prompt; // Default to just the button's prompt

        if (kind === 'clinic') {
            this.selectedClinicId = id || '';
            this.selectedDepartmentId = '';
            await this.loadCompatibility();
            
        } else if (kind === 'department') {
            this.selectedDepartmentId = id || '';
            
            // --- THE ENHANCEMENT ---
            // If they have both selected, build a combo sentence!
            const selectedClinic = this.clinics.find(c => c.Id === this.selectedClinicId);
            const selectedDept = this.departments.find(d => d.Id === this.selectedDepartmentId);
            
            if (selectedClinic && selectedDept) {
                const clinicLocation = selectedClinic.City ? ` in ${selectedClinic.City}` : '';
                textToCopy = `Select ${selectedClinic.Name}${clinicLocation} as my hospital and ${selectedDept.Name} as my department.`;
            }
            
            await this.loadCompatibility();
        }

        try {
            await navigator.clipboard.writeText(textToCopy); // Push the combo text to clipboard
            this.copiedKey = copyKey || '';
            this.copiedMessage = 'Copied. Paste it into the chat when ready.';
        } catch (error) {
            this.copiedKey = copyKey || '';
            this.copiedMessage = textToCopy; 
        }
    }
    
    async loadCompatibility() {
        if (!this.selectedClinicId) {
            return;
        }

        try {
            const result = await getCompatibility({
                territoryId: this.selectedClinicId,
                workTypeGroupId: this.selectedDepartmentId || null
            });
            this.validDepartmentIds = result?.validDepartmentIds || [];
            this.validDoctorIds = result?.validDoctorIds || [];
            this.scopedDoctors = result?.doctors || [];
        } catch (error) {
            this.copiedMessage = 'Could not validate options right now. Apex will still validate before booking.';
        }
    }

    formatSlot(startValue, endValue) {
        const start = this.formatDateTime(startValue);
        const end = this.formatTime(endValue);
        return end ? `${start} - ${end}` : start;
    }

    formatSlotPrompt(startValue, endValue) {
        const start = this.formatDateTime(startValue);
        const end = this.formatTime(endValue);
        return end ? `${start} to ${end}` : start;
    }

    formatDateTime(value) {
        const date = this.parseDate(value);
        if (!date) {
            return value;
        }
        return new Intl.DateTimeFormat(undefined, {
            timeZone: 'Asia/Kolkata',
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: 'numeric',
            minute: '2-digit'
        }).format(date);
    }

    formatTime(value) {
        const date = this.parseDate(value);
        if (!date) {
            return '';
        }
        return new Intl.DateTimeFormat(undefined, {
            timeZone: 'Asia/Kolkata',
            hour: 'numeric',
            minute: '2-digit'
        }).format(date);
    }

    formatDoctorName(name) {
        if (!name) {
            return 'Doctor';
        }
        return name.trim().toLowerCase().startsWith('dr.') ? name.trim() : `Dr. ${name.trim()}`;
    }

    getSelectableButtonClass(copyKey, isSelected, isDisabled) {
        const classes = ['pill-button'];
        if (this.copiedKey === copyKey) {
            classes.push('copied');
        }
        if (isSelected) {
            classes.push('selected');
        }
        if (isDisabled) {
            classes.push('disabled');
        }
        return classes.join(' ');
    }

    parseDate(value) {
        if (!value || typeof value !== 'string') {
            return null;
        }
        const normalized = value.replace(/([+-]\d{2})(\d{2})$/, '$1:$2');
        const date = new Date(normalized);
        return Number.isNaN(date.getTime()) ? null : date;
    }
}
