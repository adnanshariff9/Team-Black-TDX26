public without sharing class OncoSchedulerBase {
    public class CurrentPatientContext {
        public String accountId;
        public String email;
        public String phone;
    }

    public class CompatibilityResponse {
        @AuraEnabled public List<String> validDepartmentIds;
        @AuraEnabled public List<String> validDoctorIds;
        @AuraEnabled public List<ServiceResource> doctors;
    }
    
    // --- UTILITY: Get Current Logged-In Patient ---
    // Automatically finds the Community User's Person Account
    private static String getCurrentPatientId() {
        return getCurrentPatientContext().accountId;
    }

    private static CurrentPatientContext getCurrentPatientContext() {
        CurrentPatientContext context = new CurrentPatientContext();
        List<User> users = [SELECT AccountId, Contact.AccountId, Email, Phone FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (!users.isEmpty()) {
            context.email = users[0].Email;
            context.phone = users[0].Phone;
            if (users[0].AccountId != null) {
                context.accountId = users[0].AccountId;
                return context;
            }
            if (users[0].Contact != null && users[0].Contact.AccountId != null) {
                context.accountId = users[0].Contact.AccountId;
                return context;
            }
        }
        // Fallback for when you test the bot inside Salesforce Admin Setup
        List<Account> dummy = [SELECT Id FROM Account LIMIT 1];
        context.accountId = dummy.isEmpty() ? null : dummy[0].Id;
        return context;
    }

    // --- ACTION 1: Find Clinics ---
    public static List<ServiceTerritory> getClinics(String locationKeyword) {
        if (String.isBlank(locationKeyword)) {
            return [SELECT Id, Name, City FROM ServiceTerritory WHERE IsActive = true LIMIT 10];
        }
        String searchKey = '%' + locationKeyword + '%';
        return [SELECT Id, Name, City FROM ServiceTerritory WHERE IsActive = true AND (City LIKE :searchKey OR Name LIKE :searchKey)];
    }

    public static List<ServiceTerritory> getClinicById(String territoryId) {
        if (String.isBlank(territoryId)) {
            return new List<ServiceTerritory>();
        }
        return [SELECT Id, Name, City FROM ServiceTerritory WHERE Id = :territoryId LIMIT 1];
    }

    // --- ACTION 2: Find Departments ---
    public static List<WorkTypeGroup> getDepartments(String keyword) {
        if (String.isBlank(keyword)) {
            return [SELECT Id, Name FROM WorkTypeGroup WHERE IsActive = true LIMIT 20];
        }
        String searchKey = '%' + keyword + '%';
        return [SELECT Id, Name FROM WorkTypeGroup WHERE IsActive = true AND Name LIKE :searchKey];
    }

    // --- NEW ACTION 3: Get Doctors at a Clinic ---
    public static List<ServiceResource> getDoctors(String territoryId) {
        List<ServiceTerritoryMember> stms = [SELECT ServiceResource.Id, ServiceResource.Name, ServiceResource.ResourceType 
                                             FROM ServiceTerritoryMember 
                                             WHERE ServiceTerritoryId = :territoryId 
                                             AND ServiceResource.IsActive = true];
        List<ServiceResource> doctors = new List<ServiceResource>();
        for(ServiceTerritoryMember stm : stms) {
            doctors.add(stm.ServiceResource);
        }
        return doctors;
    }

    public static List<ServiceResource> searchDoctors(String keyword, String territoryId) {
        if (String.isBlank(territoryId)) {
            if (String.isBlank(keyword)) {
                return [SELECT Id, Name, ResourceType FROM ServiceResource WHERE IsActive = true LIMIT 10];
            }
            String searchKey = '%' + keyword + '%';
            return [SELECT Id, Name, ResourceType FROM ServiceResource WHERE IsActive = true AND Name LIKE :searchKey LIMIT 10];
        }

        String searchKey = String.isBlank(keyword) ? null : '%' + keyword + '%';
        List<ServiceTerritoryMember> stms = searchKey == null
            ? [SELECT ServiceResource.Id, ServiceResource.Name, ServiceResource.ResourceType
               FROM ServiceTerritoryMember
               WHERE ServiceTerritoryId = :territoryId
               AND ServiceResource.IsActive = true
               LIMIT 20]
            : [SELECT ServiceResource.Id, ServiceResource.Name, ServiceResource.ResourceType
               FROM ServiceTerritoryMember
               WHERE ServiceTerritoryId = :territoryId
               AND ServiceResource.IsActive = true
               AND ServiceResource.Name LIKE :searchKey
               LIMIT 20];

        List<ServiceResource> doctors = new List<ServiceResource>();
        for (ServiceTerritoryMember stm : stms) {
            doctors.add(stm.ServiceResource);
        }
        return doctors;
    }

    public static Boolean isDoctorAtClinic(String doctorId, String territoryId) {
        if (String.isBlank(doctorId) || String.isBlank(territoryId)) {
            return false;
        }
        return [
            SELECT COUNT()
            FROM ServiceTerritoryMember
            WHERE ServiceTerritoryId = :territoryId
            AND ServiceResourceId = :doctorId
            AND ServiceResource.IsActive = true
        ] > 0;
    }

    public static String validateDoctorForSelection(String territoryId, String workTypeGroupId, String doctorId) {
        if (String.isBlank(doctorId)) {
            return null;
        }
        if (!isDoctorAtClinic(doctorId, territoryId)) {
            return 'The selected doctor is not available at the selected hospital.';
        }

        String slots = getAvailableTimeSlots(territoryId, workTypeGroupId, doctorId);
        if (String.isBlank(slots) || slots == '[]' || slots == 'null') {
            return 'The selected doctor does not have available slots for the selected hospital and department.';
        }
        if (slots.startsWith('Error')) {
            return slots.removeStart('Error: ').removeStart('Error calculating slots: ');
        }
        return null;
    }

    @AuraEnabled
    public static CompatibilityResponse getCompatibility(String territoryId, String workTypeGroupId) {
        CompatibilityResponse response = new CompatibilityResponse();
        response.validDepartmentIds = new List<String>();
        response.validDoctorIds = new List<String>();
        response.doctors = new List<ServiceResource>();

        if (String.isBlank(territoryId)) {
            return response;
        }

        response.doctors = searchDoctors(null, territoryId);

        for (WorkTypeGroup department : getDepartments(null)) {
            String slots = getAvailableTimeSlots(territoryId, department.Id, null);
            if (hasUsableSlots(slots)) {
                response.validDepartmentIds.add(department.Id);
            }
        }

        if (String.isNotBlank(workTypeGroupId)) {
            for (ServiceResource doctor : response.doctors) {
                String validation = validateDoctorForSelection(territoryId, workTypeGroupId, doctor.Id);
                if (validation == null) {
                    response.validDoctorIds.add(doctor.Id);
                }
            }
        } else {
            for (ServiceResource doctor : response.doctors) {
                response.validDoctorIds.add(doctor.Id);
            }
        }

        return response;
    }

    private static Boolean hasUsableSlots(String slots) {
        return !String.isBlank(slots) && slots != '[]' && slots != 'null' && !slots.startsWith('Error');
    }
    
    // --- UPGRADED ACTION 4: Get Slots (Specific Doctor OR First Available) ---
    public static String getAvailableTimeSlots(String territoryId, String workTypeGroupId) {
        return getAvailableTimeSlots(territoryId, workTypeGroupId, null);
    }

    /*public static String getAvailableTimeSlots(String territoryId, String workTypeGroupId, String doctorId) {
        try {
            List<String> resourceIdsToSearch = new List<String>();
            
            // If the user asked for a specific doctor, just search their calendar
            if (String.isNotBlank(doctorId)) {
                if (!isDoctorAtClinic(doctorId, territoryId)) {
                    return 'Error: The selected doctor is not available at the selected hospital.';
                }
                resourceIdsToSearch.add(doctorId);
            } else {
                // "First Available" - grab EVERY doctor in the clinic and check all their calendars at once!
                for(ServiceTerritoryMember stm : [SELECT ServiceResourceId FROM ServiceTerritoryMember WHERE ServiceTerritoryId = :territoryId AND ServiceResource.IsActive = true]) {
                    resourceIdsToSearch.add(stm.ServiceResourceId);
                }
            }
            
            if(resourceIdsToSearch.isEmpty()) return 'Error: No active doctors found at this hospital.';

            String startTime = System.now().format('yyyy-MM-dd\'T\'HH:mm:ssZ');
            String endTime = System.now().addDays(14).format('yyyy-MM-dd\'T\'HH:mm:ssZ');
            
            lxscheduler.GetAppointmentSlotsInput input = new lxscheduler.GetAppointmentSlotsInputBuilder()
                .setTerritoryIds(new List<String>{ territoryId })
                .setWorkTypeGroupId(workTypeGroupId)
                .setRequiredResourceIds(resourceIdsToSearch) // Magic happens here
                .setStartTime(startTime)
                .setEndTime(endTime)
                .build();
            
            return lxscheduler.SchedulerResources.getAppointmentSlots(input);
            
        } catch (Exception e) {
            return 'Error calculating slots: ' + e.getMessage();
        }
    }*/
public static String getAvailableTimeSlots(String territoryId, String workTypeGroupId, String doctorId) {
    try {
        System.debug('territoryId: ' + territoryId);
        System.debug('workTypeGroupId: ' + workTypeGroupId);
        System.debug('doctorId: ' + doctorId);

        List<String> resourceIdsToSearch = new List<String>();
        
        // If the user asked for a specific doctor, just search their calendar
        if (String.isNotBlank(doctorId)) {
            if (!isDoctorAtClinic(doctorId, territoryId)) {
                System.debug('Doctor not in clinic');
                return 'Error: The selected doctor is not available at the selected hospital.';
            }
            resourceIdsToSearch.add(doctorId);
        } else {
            for(ServiceTerritoryMember stm : [
                SELECT ServiceResourceId 
                FROM ServiceTerritoryMember 
                WHERE ServiceTerritoryId = :territoryId 
                AND ServiceResource.IsActive = true
            ]) {
                resourceIdsToSearch.add(stm.ServiceResourceId);
            }
        }

        System.debug('resourceIdsToSearch: ' + resourceIdsToSearch);

        if(resourceIdsToSearch.isEmpty()) {
            System.debug('No resources found');
            return 'Error: No active doctors found at this hospital.';
        }

        String startTime = System.now().format('yyyy-MM-dd\'T\'HH:mm:ssZ');
        String endTime = System.now().addDays(14).format('yyyy-MM-dd\'T\'HH:mm:ssZ');

        System.debug('startTime: ' + startTime);
        System.debug('endTime: ' + endTime);

        lxscheduler.GetAppointmentSlotsInput input = new lxscheduler.GetAppointmentSlotsInputBuilder()
            .setTerritoryIds(new List<String>{ territoryId })
            .setWorkTypeGroupId(workTypeGroupId)
            .setRequiredResourceIds(resourceIdsToSearch)
            .setStartTime(startTime)
            .setEndTime(endTime)
            .build();

        System.debug('Calling scheduler...');

        String slots = lxscheduler.SchedulerResources.getAppointmentSlots(input);

        System.debug('RAW SLOTS: ' + slots);
        System.debug('SLOTS LENGTH: ' + (slots != null ? slots.length() : 0));

        return slots;
        
    } catch (Exception e) {
        System.debug('ERROR: ' + e.getMessage());
        return 'Error calculating slots: ' + e.getMessage();
    }
}

    // --- UPGRADED ACTION 5: Book Appointment ---
    public static String bookAppointment(String territoryId, String workTypeGroupId, String startTimeStr, String endTimeStr) {
        return bookAppointment(territoryId, workTypeGroupId, null, startTimeStr, endTimeStr, false);
    }

    public static String bookAppointment(String territoryId, String workTypeGroupId, String doctorId, String startTimeStr, String endTimeStr) {
        return bookAppointment(territoryId, workTypeGroupId, doctorId, startTimeStr, endTimeStr, false);
    }

    public static String bookAppointment(String territoryId, String workTypeGroupId, String doctorId, String startTimeStr, String endTimeStr, Boolean whatsappConsent) {
        return bookAppointment(territoryId, workTypeGroupId, doctorId, startTimeStr, endTimeStr, whatsappConsent, null);
    }

    public static String bookAppointment(String territoryId, String workTypeGroupId, String doctorId, String startTimeStr, String endTimeStr, Boolean whatsappConsent, String whatsappPhone) {
        try {
            CurrentPatientContext patientContext = getCurrentPatientContext();
            String accountId = patientContext.accountId;

            String doctorValidationError = validateDoctorForSelection(territoryId, workTypeGroupId, doctorId);
            if (doctorValidationError != null) {
                return 'Error booking: ' + doctorValidationError;
            }
            
            List<WorkTypeGroupMember> wtgm = [SELECT WorkTypeId FROM WorkTypeGroupMember WHERE WorkTypeGroupId = :workTypeGroupId LIMIT 1];
            String workTypeId = wtgm.isEmpty() ? null : wtgm[0].WorkTypeId;

            // If First Available was chosen, assign the first doctor in the clinic to the appointment
            if (String.isBlank(doctorId)) {
                List<ServiceTerritoryMember> stms = [SELECT ServiceResourceId FROM ServiceTerritoryMember WHERE ServiceTerritoryId = :territoryId AND ServiceResource.IsActive = true LIMIT 1];
                doctorId = stms.isEmpty() ? null : stms[0].ServiceResourceId;
            }

            Datetime startDt = (Datetime)JSON.deserialize('"' + startTimeStr + '"', Datetime.class);
            Datetime endDt = (Datetime)JSON.deserialize('"' + endTimeStr + '"', Datetime.class);

            ServiceAppointment sa = new ServiceAppointment();
            sa.ParentRecordId = accountId;
            sa.ServiceTerritoryId = territoryId;
            sa.WorkTypeId = workTypeId;
            sa.SchedStartTime = startDt;
            sa.SchedEndTime = endDt;
            sa.EarliestStartTime = startDt;
            sa.DueDate = endDt; 
            sa.Subject = 'Oncology Consultation';
            sa.Status = 'Scheduled'; // Ensure it is marked active
            sa.Phone = String.isNotBlank(whatsappPhone) ? whatsappPhone : patientContext.phone;
            sa.Email = patientContext.email;
            sa.Whatsapp_Consent__c = whatsappConsent == true;
            insert sa;

            if (doctorId != null) {
                insert new AssignedResource(ServiceAppointmentId = sa.Id, ServiceResourceId = doctorId);
            }
            // Query the readable Auto-Number
            ServiceAppointment insertedSa = [SELECT AppointmentNumber FROM ServiceAppointment WHERE Id = :sa.Id LIMIT 1];
            
            return 'Success! Confirmation ID: ' + insertedSa.AppointmentNumber + '|' + sa.Id;

        } catch (Exception e) {
            return 'Error booking: ' + e.getMessage();
        }
    }

    public static String updateWhatsAppConsent(String appointmentId, String whatsappPhone, Boolean consent) {
        try {
            String accountId = getCurrentPatientId();
            List<ServiceAppointment> appointments;

            if (String.isNotBlank(appointmentId)) {
                appointments = [
                    SELECT Id, AppointmentNumber, Phone, Whatsapp_Consent__c
                    FROM ServiceAppointment
                    WHERE Id = :appointmentId
                    LIMIT 1
                ];
            } else {
                appointments = [
                    SELECT Id, AppointmentNumber, Phone, Whatsapp_Consent__c
                    FROM ServiceAppointment
                    WHERE ParentRecordId = :accountId
                    AND Status != 'Canceled'
                    AND SchedStartTime >= :System.now()
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
            }

            if (appointments.isEmpty()) {
                return 'Error: No upcoming appointment found to update WhatsApp preferences.';
            }

            ServiceAppointment sa = appointments[0];
            sa.Whatsapp_Consent__c = consent == true;
            if (String.isNotBlank(whatsappPhone)) {
                sa.Phone = whatsappPhone;
            }
            update sa;

            return 'Success! WhatsApp preferences updated for appointment ' + sa.Id;
        } catch (Exception e) {
            return 'Error updating WhatsApp preferences: ' + e.getMessage();
        }
    }

    // --- NEW ACTION 6: Get User's Current Appointments ---
    public static List<ServiceAppointment> getMyAppointments() {
        String accountId = getCurrentPatientId();
        // Fetch future appointments that haven't been canceled
        return [SELECT Id, AppointmentNumber, SchedStartTime, SchedEndTime, Status, ServiceTerritory.Name 
                FROM ServiceAppointment 
                WHERE ParentRecordId = :accountId 
                AND Status != 'Canceled' 
                AND SchedStartTime >= TODAY 
                ORDER BY SchedStartTime ASC];
    }

    // --- NEW ACTION 7: Cancel Appointment ---
    public static String cancelAppointment(String appointmentId) {
        try {
            update new ServiceAppointment(Id = appointmentId, Status = 'Canceled');
            return 'Appointment has been successfully canceled.';
        } catch (Exception e) {
            return 'Failed to cancel: ' + e.getMessage();
        }
    }

    // --- NEW ACTION 8: Reschedule Appointment ---
    public static String rescheduleAppointment(String appointmentId, String newStartTimeStr, String newEndTimeStr) {
        try {
            Datetime startDt = (Datetime)JSON.deserialize('"' + newStartTimeStr + '"', Datetime.class);
            Datetime endDt = (Datetime)JSON.deserialize('"' + newEndTimeStr + '"', Datetime.class);

            ServiceAppointment sa = new ServiceAppointment(
                Id = appointmentId,
                SchedStartTime = startDt,
                SchedEndTime = endDt,
                EarliestStartTime = startDt,
                DueDate = endDt
            );
            update sa;
            return 'Appointment successfully rescheduled to your new time.';
        } catch (Exception e) {
            return 'Failed to reschedule: ' + e.getMessage();
        }
    }
}