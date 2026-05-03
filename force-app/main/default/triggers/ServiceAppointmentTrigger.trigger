trigger ServiceAppointmentTrigger on ServiceAppointment (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        WhatsAppNotificationHandler.sendInitialNotification(Trigger.newMap.keySet());
    }
}