@RestResource(urlMapping='/whatsapp')
global without sharing class WhatsAppWebhook {
    private static final String STATUS_SCHEDULED = 'Scheduled';
    private static final String STATUS_COMPLETED = 'Completed';
    private static final String STATUS_CANCELED = 'Canceled';
    private static final String STATUS_RESCHEDULE_REQUESTED = 'Reschedule Requested';
    private static final String PENDING_CANCELLATION_REASON = 'Pending WhatsApp cancellation reason';

    @HttpPost
    global static void handleIncoming() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String fromNumber = req.params.get('From');
        String messageBody = req.params.get('Body');

        String msg = messageBody != null ? messageBody.trim().toLowerCase() : '';
        String reply;
        String cleanPhone = fromNumber != null ? fromNumber.replace('whatsapp:', '') : '';

        List<ServiceAppointment> saList = [
            SELECT Id, Status, AppointmentNumber, Whatsapp_Consent__c, CancellationReason, Case__c
            FROM ServiceAppointment
            WHERE Phone = :cleanPhone
            AND Status != :STATUS_COMPLETED
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!saList.isEmpty()) {
            ServiceAppointment sa = saList[0];
            Boolean shouldUpdate = false;
            Boolean isRescheduleRequested = sa.Status == STATUS_RESCHEDULE_REQUESTED;
            Boolean handledHelpCaseUpdate = false;

            if (sa.Case__c != null && !isMenuResponse(msg) && !String.isBlank(messageBody)) {
                try {
                    Case existingCase = [SELECT Id, Description FROM Case WHERE Id = :sa.Case__c LIMIT 1];
                    String details = messageBody.trim();
                    existingCase.Description = String.isBlank(existingCase.Description)
                        ? details
                        : existingCase.Description + '\n\nWhatsApp update: ' + details;
                    update existingCase;
                    reply = 'Thanks for the details. Your support case has been updated and our team will review it shortly.';
                } catch (Exception e) {
                    System.debug('Case Update Error: ' + e.getMessage());
                    reply = 'Sorry, we could not update your support case right now. Please call our support line at (555) 123-4567.';
                }
                handledHelpCaseUpdate = true;
            }

            if (!handledHelpCaseUpdate) {
                if (sa.Status == STATUS_CANCELED) {
                if (isMenuResponse(msg)) {
                    reply = 'This appointment (' + sa.AppointmentNumber + ') has already been canceled. If you need to book a new one, please visit our website or call us.';
                } else if (isStopRequest(msg)) {
                    sa.Whatsapp_Consent__c = false;
                    reply = 'You have been unsubscribed from WhatsApp notifications.';
                    shouldUpdate = true;
                } else {
                    reply = 'This appointment is canceled. For further assistance, please contact our support team.';
                }
            } else if (isWaitingForCancellationReason(sa)) {
                if (isStopRequest(msg)) {
                    sa.Whatsapp_Consent__c = false;
                    reply = 'You have been unsubscribed from WhatsApp notifications.';
                    shouldUpdate = true;
                } else if (String.isBlank(messageBody)) {
                    reply = 'Please share the reason for canceling appointment ' + sa.AppointmentNumber + '.';
                } else {
                    sa.Status = STATUS_CANCELED;
                    sa.CancellationReason = messageBody.trim();
                    reply = 'Appointment ' + sa.AppointmentNumber + ' has been canceled. Thank you for sharing the reason.';
                    shouldUpdate = true;
                }
            } else {
                if (isConfirmRequest(msg)) {
                    if (sa.Status == STATUS_SCHEDULED) {
                        reply = 'Appointment ' + sa.AppointmentNumber + ' is already confirmed.';
                    } else {
                        sa.Status = STATUS_SCHEDULED;
                        reply = 'Appointment ' + sa.AppointmentNumber + ' is now confirmed. Thank you!';
                        shouldUpdate = true;
                    }
                } else if (isRescheduleRequest(msg)) {
                    if (isRescheduleRequested) {
                        reply = 'We already have your reschedule request for ' + sa.AppointmentNumber + '. A team member will contact you shortly.';
                    } else {
                        sa.Status = STATUS_RESCHEDULE_REQUESTED;
                        reply = 'We have received your request to reschedule ' + sa.AppointmentNumber + '. A team member will contact you shortly to find a new time.';
                        shouldUpdate = true;
                    }
                } else if (isHelpRequest(msg)) {
                    if (sa.Case__c != null) {
                        reply = 'We already have a support case open for this appointment. Please share the details of your issue and we will update the case.';
                    } else {
                        Case helpCase = new Case(
                            Subject = 'WhatsApp help request for appointment ' + sa.AppointmentNumber,
                            Status = 'New',
                            Origin = 'Phone',
                            Description = 'WhatsApp help request from ' + cleanPhone + ' for appointment ' + sa.AppointmentNumber,
                            SuppliedPhone = cleanPhone
                        );
                        try {
                            insert helpCase;
                            sa.Case__c = helpCase.Id;
                            reply = 'A support case has been created for your appointment. Please share a few details about your issue so we can assist you faster.';
                            shouldUpdate = true;
                        } catch (Exception e) {
                            System.debug('Case Insert Error: ' + e.getMessage());
                            reply = 'Sorry, we could not create a support case right now. Please call our support line at (555) 123-4567.';
                        }
                    }
                } else if (isCancelRequest(msg)) {
                    sa.CancellationReason = PENDING_CANCELLATION_REASON;
                    reply = 'Please share the reason for canceling appointment ' + sa.AppointmentNumber + '.';
                    shouldUpdate = true;
                } else if (isStopRequest(msg)) {
                    sa.Whatsapp_Consent__c = false;
                    reply = 'You have been unsubscribed from WhatsApp notifications.';
                    shouldUpdate = true;
                } else {
                    reply = 'Please reply with a number:\n1 Confirm Appointment\n2 Reschedule Appointment\n3 Need Help?\n4 Cancel Appointment\n\nType STOP to unsubscribe.';
                }
            }
        }

            if (shouldUpdate) {
                try {
                    update sa;
                } catch (Exception e) {
                    System.debug('Update Error: ' + e.getMessage());
                    reply = 'Sorry, we encountered an error updating your appointment.';
                }
            }
        } else {
            reply = 'No active appointment found for this number. If you need assistance, please contact us directly.';
        }

        String twiml = '<Response><Message>' + escapeXml(reply) + '</Message></Response>';
        res.addHeader('Content-Type', 'text/xml');
        res.responseBody = Blob.valueOf(twiml);
    }

    private static Boolean isConfirmRequest(String msg) {
        return msg == '1' || msg == 'confirm' || msg == 'confirmed';
    }

    private static Boolean isRescheduleRequest(String msg) {
        return msg == '2' || msg == 'reschedule' || msg == 'reschedule requested';
    }

    private static Boolean isHelpRequest(String msg) {
        return msg == '3' || msg == 'help';
    }

    private static Boolean isCancelRequest(String msg) {
        return msg == '4'
            || msg == 'cancel'
            || msg == 'cancel appointment'
            || msg == 'canceled'
            || msg == 'cancelled'
            || msg.startsWith('4 ')
            || msg.startsWith('cancel ')
            || msg.startsWith('cancel appointment ')
            || msg.startsWith('canceled ')
            || msg.startsWith('cancelled ');
    }

    private static Boolean isWaitingForCancellationReason(ServiceAppointment sa) {
        return sa.CancellationReason == PENDING_CANCELLATION_REASON;
    }

    private static Boolean isStopRequest(String msg) {
        return msg == 'stop' || msg == 'unsubscribe';
    }

    private static Boolean isMenuResponse(String msg) {
        return isConfirmRequest(msg) || isRescheduleRequest(msg) || isHelpRequest(msg) || isCancelRequest(msg);
    }

    private static String escapeXml(String value) {
        if (value == null) {
            return '';
        }

        return value
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&apos;');
    }
}