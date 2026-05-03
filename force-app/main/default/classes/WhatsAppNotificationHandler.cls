public class WhatsAppNotificationHandler {

    @future(callout=true)
    public static void sendInitialNotification(Set<Id> saIds) {
        List<ServiceAppointment> appointments = getAppointmentDetails(saIds);
        
        Set<String> phoneNumbers = new Set<String>();
        for(ServiceAppointment sa : appointments) {
            if(String.isNotBlank(sa.Phone)) phoneNumbers.add(sa.Phone);
        }

        List<ServiceAppointment> existingSAs = [
            SELECT Phone 
            FROM ServiceAppointment 
            WHERE Phone IN :phoneNumbers AND Id NOT IN :saIds AND Whatsapp_Consent__c = true
            LIMIT 1000
        ];
        
        Set<String> repeatPhones = new Set<String>();
        for(ServiceAppointment esa : existingSAs) {
            repeatPhones.add(esa.Phone);
        }

        processNotifications(appointments, repeatPhones, 'Appointment Confirmation');
    }

    public static void sendReminders() {
        DateTime target24h = DateTime.now().addHours(24);
        DateTime target1h = DateTime.now().addHours(1);

        List<ServiceAppointment> appointments = [
            SELECT Id, AppointmentNumber, Status, SchedStartTime, SchedEndTime, Subject,
                   WorkType.Name, ServiceTerritory.Name,
                   Phone, Email, Whatsapp_Consent__c
            FROM ServiceAppointment
            WHERE Status = 'Scheduled'
            AND (
                (SchedStartTime >= :target24h.addMinutes(-30) AND SchedStartTime <= :target24h.addMinutes(30))
                OR (SchedStartTime >= :target1h.addMinutes(-30) AND SchedStartTime <= :target1h.addMinutes(30))
            )
        ];

        if (!appointments.isEmpty()) {
            processNotifications(appointments, new Set<String>(), 'Appointment Reminder');
        }
    }

    private static List<ServiceAppointment> getAppointmentDetails(Set<Id> saIds) {
        return [
            SELECT Id, AppointmentNumber, SchedStartTime, SchedEndTime, Subject,
                   WorkType.Name, ServiceTerritory.Name, 
                   Phone, Email, Whatsapp_Consent__c 
            FROM ServiceAppointment 
            WHERE Id IN :saIds
        ];
    }

    private static void processNotifications(List<ServiceAppointment> appointments, Set<String> repeatPhones, String subjectPrefix) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<OrgWideEmailAddress> owea = [
            SELECT Id, Address
            FROM OrgWideEmailAddress
            LIMIT 100
        ];

        for (ServiceAppointment sa : appointments) {
            if (String.isNotBlank(sa.Email)) {
                emails.add(generateAppointmentEmail(sa, owea, subjectPrefix, repeatPhones.contains(sa.Phone)));
            }
            
            if (sa.Whatsapp_Consent__c == true && String.isNotBlank(sa.Phone)) {
                if (repeatPhones.contains(sa.Phone) || subjectPrefix.contains('Reminder')) {
                    sendTwilioWhatsApp(sa, subjectPrefix);
                }
            }
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    private static void sendTwilioWhatsApp(ServiceAppointment sa, String subjectPrefix) {
        String startTimeStr = sa.SchedStartTime != null ? sa.SchedStartTime.format('EEE, MMM d, h:mm a') : 'TBD';
        String location = sa.ServiceTerritory != null ? sa.ServiceTerritory.Name : 'Remote';
        
        String whatsappMessage = '✨ *' + subjectPrefix.toUpperCase() + '* ✨\n\n' +
            'Hello! 👋\n\n' +
            'Your appointment *' + sa.AppointmentNumber + '* details:\n' +
            '🗓 *Date:* ' + startTimeStr + '\n' +
            '📍 *Location:* ' + location + '\n\n' +
            'Please reply with a number:\n' +
            '1️⃣ *Confirm Appointment*\n' +
            '2️⃣ *Reschedule Appointment*\n' +
            '3️⃣ *Need Help?*\n' +
            '4️⃣ *Cancel Appointment*\n\n' +
            'We look forward to seeing you! 😊';

        WhatsAppService.sendMessage(sa.Phone, whatsappMessage);
    }

    private static Messaging.SingleEmailMessage generateAppointmentEmail(ServiceAppointment sa, List<OrgWideEmailAddress> owea, String subjectPrefix, Boolean hasJoinedWA) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        Id orgWideEmailAddressId = getDeliverableOrgWideEmailAddressId(owea);
        if (orgWideEmailAddressId != null) mail.setOrgWideEmailAddressId(orgWideEmailAddressId);
        mail.setToAddresses(new String[] {sa.Email});
        mail.setSubject(subjectPrefix + ': ' + sa.AppointmentNumber);
        
        String startTimeStr = sa.SchedStartTime != null ? sa.SchedStartTime.format('EEEE, MMMM d, yyyy \'at\' h:mm a') : 'TBD';
        String location = sa.ServiceTerritory != null ? sa.ServiceTerritory.Name : 'Remote / To Be Determined';
        String serviceTitle = String.isNotBlank(sa.Subject) ? sa.Subject : (sa.WorkType != null ? sa.WorkType.Name : 'Service Appointment');
        //String waUrl = 'https://wa.me/14155238886?text=join%20closely-taken';
       String waUrl = 'https://wa.me/14155238886?text=' + 
    EncodingUtil.urlEncode('join closely-taken', 'UTF-8');
        String plainBody =
            subjectPrefix + '\n\n' +
            'Hello Patient,\n\n' +
            'Your appointment ' + sa.AppointmentNumber + ' has been scheduled.\n\n' +
            'Service: ' + serviceTitle + '\n' +
            'Date & Time: ' + startTimeStr + '\n' +
            'Location: ' + location + '\n\n' +
            //(sa.Whatsapp_Consent__c == true && !hasJoinedWA ? 'Manage this appointment via WhatsApp: ' + waUrl + '\n\n' : '') +
            (sa.Whatsapp_Consent__c == true && !hasJoinedWA ? 'You can manage your appointment via WhatsApp using the button below.\n\n' : '') +
            'Thank you for choosing our services.\n' +
            'Automated Appointment System';
        
        String htmlBody = 
            '<div style="font-family: \'Helvetica Neue\', Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto; background-color: #ffffff; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">' +
                '<div style="background-color: #0070D2; padding: 24px; text-align: center;">' +
                    '<h1 style="color: #ffffff; margin: 0; font-size: 22px; font-weight: 600;">' + subjectPrefix + '</h1>' +
                '</div>' +
                '<div style="padding: 32px;">' +
                    '<p style="font-size: 16px; color: #333333; margin-top: 0;">Hello,</p>' +
                    '<p style="font-size: 16px; color: #333333;">Your appointment <strong>' + sa.AppointmentNumber + '</strong> has been scheduled. Please review the details below:</p>' +
                    '<div style="margin: 28px 0; border: 1px solid #eeeeee; border-radius: 6px; overflow: hidden;">' +
                        '<table style="width: 100%; border-collapse: collapse; font-size: 15px; text-align: left;">' +
                            '<tr><th style="padding: 14px 16px; background-color: #f8f9fa; color: #555555; width: 35%; border-bottom: 1px solid #eeeeee;">Service</th>' +
                            '<td style="padding: 14px 16px; border-bottom: 1px solid #eeeeee;">' + serviceTitle + '</td></tr>' +
                            '<tr><th style="padding: 14px 16px; background-color: #f8f9fa; color: #555555; border-bottom: 1px solid #eeeeee;">Date & Time</th>' +
                            '<td style="padding: 14px 16px; border-bottom: 1px solid #eeeeee;">' + startTimeStr + '</td></tr>' +
                            '<tr><th style="padding: 14px 16px; background-color: #f8f9fa; color: #555555;">Location</th>' +
                            '<td style="padding: 14px 16px;">' + location + '</td></tr>' +
                        '</table>' +
                    '</div>';

        if (sa.Whatsapp_Consent__c == true && !hasJoinedWA) {
            htmlBody += 
                '<div style="margin-top: 32px; padding: 24px; background-color: #f2fbf5; border-radius: 6px; text-align: center; border: 1px solid #b7ebd0;">' +
                    '<p style="font-size: 15px; color: #2c3e50; margin-bottom: 16px; font-weight: 500;">Manage this appointment via WhatsApp:</p>' +
                    '<a href="' + waUrl + '" style="background-color: #25D366; color: #ffffff; padding: 14px 28px; text-decoration: none; border-radius: 4px; font-weight: bold; display: inline-block;">Connect to WhatsApp</a>' +
                '</div>';
        }

        htmlBody += 
                '<p style="font-size: 14px; color: #555555; margin-top: 32px;">Thank you for choosing our services.</p>' +
                '<div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #eeeeee; text-align: center;">' +
                    '<p style="font-size: 12px; color: #999999;">Automated Appointment System</p>' +
                '</div>' +
            '</div></div>';
            
        mail.setPlainTextBody(plainBody);
        mail.setHtmlBody(htmlBody);
        return mail;
    }

    private static Id getDeliverableOrgWideEmailAddressId(List<OrgWideEmailAddress> orgWideEmailAddresses) {
        for (OrgWideEmailAddress orgWideEmailAddress : orgWideEmailAddresses) {
            String address = orgWideEmailAddress.Address != null ? orgWideEmailAddress.Address.toLowerCase() : '';
            if (!isConsumerEmailAddress(address)) {
                return orgWideEmailAddress.Id;
            }
        }

        return null;
    }

    private static Boolean isConsumerEmailAddress(String address) {
        return false;/*address.endsWith('@gmail.com') ||
            address.endsWith('@googlemail.com') ||
            address.endsWith('@yahoo.com') ||
            address.endsWith('@outlook.com') ||
            address.endsWith('@hotmail.com') ||
            address.endsWith('@live.com');*/
    }
}