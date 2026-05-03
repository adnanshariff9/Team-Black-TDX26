public without sharing class AgentManageAppointmentAction {
    public class AppointmentRequest {
        @InvocableVariable(required=true description='Operation to perform: discover, getDoctors, getSlots, book, listAppointments, cancel, reschedule, whatsappConsent.')
        public String operation;

        @InvocableVariable(description='City, hospital, department, specialty, or doctor keyword supplied by the patient.')
        public String searchText;

        @InvocableVariable(description='Salesforce ID of the clinic or hospital ServiceTerritory.')
        public String territoryId;

        @InvocableVariable(description='Salesforce ID of the department WorkTypeGroup.')
        public String workTypeGroupId;

        @InvocableVariable(description='Optional Salesforce ID of a specific doctor ServiceResource. Leave blank for first available.')
        public String doctorId;

        @InvocableVariable(description='Salesforce ID of the ServiceAppointment for cancel or reschedule.')
        public String appointmentId;

        @InvocableVariable(description='Appointment start time in ISO 8601 format.')
        public String startTime;

        @InvocableVariable(description='Appointment end time in ISO 8601 format.')
        public String endTime;

        @InvocableVariable(description='Patient consent to receive WhatsApp notifications for the appointment.')
        public Boolean whatsappConsent;

        @InvocableVariable(description='Patient WhatsApp phone number, including country code when available.')
        public String whatsappPhone;
    }

    public class AppointmentResult {
        @InvocableVariable(description='Structured scheduling response for Agentforce custom LWC rendering.')
        public OncoAgentResponse response;
    }

    @InvocableMethod(
        label='Manage Oncology Appointment'
        description='One Agentforce action for discovering clinics, departments, doctors, slots, booking, listing, canceling, rescheduling, and WhatsApp opt-in.'
    )
    public static List<AppointmentResult> manage(List<AppointmentRequest> requests) {
        List<AppointmentResult> responses = new List<AppointmentResult>();
        for (AppointmentRequest req : requests) {
            AppointmentResult result = new AppointmentResult();
            result.response = handle(req);
            responses.add(result);
        }
        return responses;
    }

    private static OncoAgentResponse handle(AppointmentRequest req) {
        if (req == null || String.isBlank(req.operation)) {
            return response('NeedsInput', 'What would you like to do?', 'Please choose whether you want to find care, book, reschedule, cancel, or manage WhatsApp updates.', '{}', 'Ask the patient for their scheduling goal.');
        }

        String operation = req.operation.trim().toLowerCase();
        try {
            if (operation == 'discover' || operation == 'search') {
                return discover(req);
            }
            if (operation == 'getdoctors' || operation == 'doctors') {
                return getDoctors(req);
            }
            if (operation == 'getslots' || operation == 'slots') {
                return getSlots(req);
            }
            if (operation == 'book') {
                return book(req);
            }
            if (operation == 'listappointments' || operation == 'list' || operation == 'myappointments') {
                return listAppointments();
            }
            if (operation == 'cancel') {
                return cancel(req);
            }
            if (operation == 'reschedule') {
                return reschedule(req);
            }
            if (operation == 'whatsappconsent' || operation == 'whatsapp') {
                return whatsappConsent(req);
            }
            return response('NeedsInput', 'Unsupported request', 'I can help with discovery, slots, booking, appointment changes, and WhatsApp consent.', '{}', 'Ask the patient to rephrase their request.');
        } catch (Exception e) {
            return response('Error', 'Scheduling issue', e.getMessage(), '{}', 'Try again with confirmed clinic, department, and appointment details.');
        }
    }

    private static OncoAgentResponse discover(AppointmentRequest req) {
        String keyword = req.searchText;
        Map<String, Object> payload = new Map<String, Object>();
        List<ServiceTerritory> clinics = String.isNotBlank(req.territoryId)
            ? OncoSchedulerBase.getClinicById(req.territoryId)
            : OncoSchedulerBase.getClinics(keyword);
        List<WorkTypeGroup> departments = OncoSchedulerBase.getDepartments(keyword);
        List<ServiceResource> doctors = new List<ServiceResource>();
        if (String.isNotBlank(req.territoryId) || String.isNotBlank(keyword)) {
            doctors = OncoSchedulerBase.searchDoctors(keyword, req.territoryId);
        }
        payload.put('clinics', clinics);
        payload.put('departments', departments);
        payload.put('doctors', doctors);

        if (clinics.isEmpty() && departments.isEmpty() && doctors.isEmpty()) {
            return response('NoResults', 'No matching care options', 'I could not find a matching hospital, department, or doctor. Try another city, specialty, cancer type, or doctor name.', JSON.serialize(payload), 'Ask for a different location, specialty, or doctor.');
        }
        return response('Success', 'Care options found', 'I found matching care options. Select a hospital first, then select a department. Only offer doctors after the hospital is selected.', JSON.serialize(payload), 'Guide the patient step by step: clinic first, department second, doctor or first available third.');
    }

    private static OncoAgentResponse getDoctors(AppointmentRequest req) {
        if (String.isBlank(req.territoryId)) {
            return response('NeedsInput', 'Hospital needed', 'Please select a hospital before I look up doctors.', '{}', 'Collect territoryId from a clinic search result.');
        }

        List<ServiceResource> doctors = OncoSchedulerBase.searchDoctors(req.searchText, req.territoryId);
        Map<String, Object> payload = new Map<String, Object>{ 'doctors' => doctors };
        if (doctors.isEmpty()) {
            return response('NoResults', 'No doctors found', 'I could not find matching doctors at that hospital.', JSON.serialize(payload), 'Offer first available appointment slots for the selected department.');
        }
        return response('Success', 'Doctors found', 'I found doctors available at this hospital. Confirm the department before checking appointment slots.', JSON.serialize(payload), 'Ask whether the patient wants one of these doctors or the first available appointment for the selected department.');
    }

    private static OncoAgentResponse getSlots(AppointmentRequest req) {
        if (String.isBlank(req.territoryId) || String.isBlank(req.workTypeGroupId)) {
            return response('NeedsInput', 'Clinic and department needed', 'Please select a hospital and department before I check appointment times.', '{}', 'Collect territoryId and workTypeGroupId.');
        }
        String validationError = OncoSchedulerBase.validateDoctorForSelection(req.territoryId, req.workTypeGroupId, req.doctorId);
        if (validationError != null) {
            return response('NoResults', 'Doctor unavailable for selection', validationError, '{"slots":[]}', 'Ask the patient to choose another doctor or continue with first available slots by leaving doctor blank.');
        }
        String slots = OncoSchedulerBase.getAvailableTimeSlots(req.territoryId, req.workTypeGroupId, req.doctorId);
        if (String.isBlank(slots) || slots == '[]' || slots == 'null' || slots.startsWith('Error')) {
            return response('NoResults', 'No slots found', slots.startsWith('Error') ? slots : 'No available time slots were found for that selection.', '{"slots":[]}', 'Offer a different doctor, department, hospital, or date range.');
        }
        return response('Success', 'Available appointment times', 'Here are available appointment times for your selected care team.', '{"slots":' + slots + '}', 'Ask the patient to choose one slot.');
    }

    private static OncoAgentResponse book(AppointmentRequest req) {
        if (String.isBlank(req.territoryId) || String.isBlank(req.workTypeGroupId) || String.isBlank(req.startTime) || String.isBlank(req.endTime)) {
            return response('NeedsInput', 'Booking details needed', 'Please choose a hospital, department, and appointment time before I book it.', '{}', 'Collect clinic, department, start time, and end time.');
        }
        
        String result = OncoSchedulerBase.bookAppointment(req.territoryId, req.workTypeGroupId, req.doctorId, req.startTime, req.endTime, req.whatsappConsent, req.whatsappPhone);
        
        String status = result.startsWith('Success') ? 'Success' : 'Error';
        String displayMessage = result;
        String appointmentId = '';

        // --- THE ENHANCEMENT ---
        // If successful, split the message to give the user the readable number, and keep the ID for the JSON
        if (status == 'Success') {
            List<String> parts = result.split('\\|');
            if (parts.size() == 2) {
                displayMessage = parts[0]; // e.g., "Success! Confirmation ID: SA-0001"
                appointmentId = parts[1];  // e.g., "08p..."
            }
        } else {
            appointmentId = extractAppointmentId(result); // Fallback for errors
        }

        String payload = '{"confirmation":"' + escapeJson(displayMessage) + '","appointmentId":"' + escapeJson(appointmentId) + '"}';
        return response(status, status == 'Success' ? 'Appointment booked' : 'Booking failed', displayMessage, payload, req.whatsappConsent == true ? 'Tell the patient WhatsApp updates are enabled.' : 'Ask whether the patient wants WhatsApp reminders. If they opt in, pass appointmentId from this response.');
    }
    
    // private static OncoAgentResponse book(AppointmentRequest req) {
    //     if (String.isBlank(req.territoryId) || String.isBlank(req.workTypeGroupId) || String.isBlank(req.startTime) || String.isBlank(req.endTime)) {
    //         return response('NeedsInput', 'Booking details needed', 'Please choose a hospital, department, and appointment time before I book it.', '{}', 'Collect clinic, department, start time, and end time.');
    //     }
    //     String result = OncoSchedulerBase.bookAppointment(req.territoryId, req.workTypeGroupId, req.doctorId, req.startTime, req.endTime, req.whatsappConsent, req.whatsappPhone);
    //     String status = result.startsWith('Success') ? 'Success' : 'Error';
    //     String appointmentId = extractAppointmentId(result);

    //     String payload = '{"confirmation":"' + escapeJson(result) + '","appointmentId":"' + escapeJson(appointmentId) + '"}';
    //     return response(status, status == 'Success' ? 'Appointment booked' : 'Booking failed', result, payload, req.whatsappConsent == true ? 'Tell the patient WhatsApp updates are enabled.' : 'Ask whether the patient wants WhatsApp reminders. If they opt in, pass appointmentId from this response.');
    // }

    private static OncoAgentResponse listAppointments() {
        List<ServiceAppointment> appointments = OncoSchedulerBase.getMyAppointments();
        if (appointments.isEmpty()) {
            return response('NoResults', 'No upcoming appointments', 'You do not have any upcoming appointments scheduled.', '{"appointments":[]}', 'Offer to book a new appointment.');
        }
        return response('Success', 'Upcoming appointments', 'Here are the upcoming appointments I found.', JSON.serialize(new Map<String, Object>{ 'appointments' => appointments }), 'Ask which appointment the patient wants to change.');
    }

    private static OncoAgentResponse cancel(AppointmentRequest req) {
        if (String.isBlank(req.appointmentId)) {
            return response('NeedsInput', 'Appointment needed', 'Please choose the appointment you want to cancel.', '{}', 'Use listAppointments first, then ask the patient to select one.');
        }
        String result = OncoSchedulerBase.cancelAppointment(req.appointmentId);
        return response(result.startsWith('Appointment') ? 'Success' : 'Error', 'Cancel appointment', result, '{"appointmentId":"' + escapeJson(req.appointmentId) + '"}', 'Confirm the cancellation outcome to the patient.');
    }

    private static OncoAgentResponse reschedule(AppointmentRequest req) {
        if (String.isBlank(req.appointmentId) || String.isBlank(req.startTime) || String.isBlank(req.endTime)) {
            return response('NeedsInput', 'New time needed', 'Please choose the appointment and a new time before I reschedule it.', '{}', 'Collect appointmentId, startTime, and endTime.');
        }
        String result = OncoSchedulerBase.rescheduleAppointment(req.appointmentId, req.startTime, req.endTime);
        return response(result.startsWith('Appointment') ? 'Success' : 'Error', 'Reschedule appointment', result, '{"appointmentId":"' + escapeJson(req.appointmentId) + '"}', 'Confirm the new appointment time.');
    }

    private static OncoAgentResponse whatsappConsent(AppointmentRequest req) {
        if (req.whatsappConsent != true) {
            return response('Success', 'WhatsApp not enabled', 'No problem. WhatsApp updates will stay turned off unless you opt in later.', '{}', 'Continue the appointment flow without WhatsApp.');
        }
        if (String.isBlank(req.whatsappPhone)) {
            return response('NeedsInput', 'WhatsApp number needed', 'Please provide the WhatsApp mobile number where you want to receive updates.', '{}', 'Ask for the patient WhatsApp number with country code.');
        }
        String result = OncoSchedulerBase.updateWhatsAppConsent(req.appointmentId, req.whatsappPhone, true);
        if (!result.startsWith('Success')) {
            return response('Error', 'WhatsApp update failed', result, '{}', 'Ask the patient to choose the appointment and try again.');
        }
        WhatsAppService.sendMessageAsync(req.whatsappPhone, 'You are opted in to Onco Global appointment updates. Reply STOP to unsubscribe.');
        return response('Success', 'WhatsApp enabled', 'WhatsApp appointment updates are enabled for this appointment.', '{"phone":"' + escapeJson(req.whatsappPhone) + '","appointmentId":"' + escapeJson(extractAppointmentId(result)) + '"}', 'Proceed with booking or appointment management.');
    }

    private static OncoAgentResponse response(String status, String title, String message, String dataJson, String nextAction) {
        OncoAgentResponse res = new OncoAgentResponse();
        res.status = status;
        res.title = title;
        res.message = message;
        res.payloadJson = dataJson;
        res.nextAction = nextAction;
        return res;
    }

    private static String escapeJson(String value) {
        return value == null ? '' : value.replace('\\', '\\\\').replace('"', '\\"');
    }

    private static String extractAppointmentId(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        Integer index = value.lastIndexOf(' ');
        return index >= 0 ? value.substring(index + 1).trim() : '';
    }
}
